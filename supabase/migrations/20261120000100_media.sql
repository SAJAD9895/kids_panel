-- Phase 11: multimedia (videos, songs, stories). docs/multimedia/media-architecture.md.
--
-- 1. screen_time_rules.blocked_category_ids (NEW COLUMN, documented in database-schema.md §5 #11)
--    WHY: the brief asks for "parent-controlled access to media categories". The reviewed schema
--    only had whole-section switches (watch / listen). One array column on the existing per-child
--    rules row is the smallest change: no new table, the same RLS (parents of the child read it),
--    and the same write path. Default '{}' = nothing blocked, so existing rows are unchanged.
-- 1b. activity_media.text (NEW COLUMN, database-schema.md §5 #12)
--    WHY: an illustrated story is pages of picture + words. The pictures are page_image rows; the
--    words (shown on screen and read by the narration voice) had nowhere to live. A localized text
--    column on the page's activity_media row keeps each page in one row. Null for other roles.
-- 2. private.launch(user, {childId, activityId})          → POST /play/launch (the gate)
-- 3. private.add_screen_time(user, child, section, secs)  → POST /play/heartbeat (playback limits)
-- 4. private.set_screen_time_rules(user, child, rules)    → PUT /children/:id/screen-time
--
-- Same pattern as 0012 / 0014 / 0015: security definer, empty search_path, service-only, the user
-- id comes from the verified JWT, the child must belong to that parent's household (404 if not).
-- Error codes: KL400 validation, KL402 NEEDS_PLUS, KL403 AGE_NOT_SUITABLE, KL404 not found,
-- KL423 SECTION_DISABLED / CATEGORY_BLOCKED / SCREEN_TIME_OVER (the message names which).
--
-- Resume positions are NOT a new table: a media session that ends early is reported to
-- play/sync as `abandoned` with metrics {positionMs, durationMs} (videos, songs) or {page, pages}
-- (stories); launch returns the latest unfinished one as `resume`.

alter table public.screen_time_rules
  add column blocked_category_ids uuid[] not null default '{}'
    check (cardinality(blocked_category_ids) <= 50);

alter table public.activity_media
  add column text jsonb check (text is null or (jsonb_typeof(text) = 'object' and pg_column_size(text) <= 4096));

comment on column public.activity_media.text is
  'Localized words for a story page ({"en": "..."}), shown and narrated with the page_image';

comment on column public.screen_time_rules.blocked_category_ids is
  'Categories (categories.id) a parent switched off for this child: their items are hidden and launch refuses them';

-- The section a kind of activity belongs to (screen_time_rules / screen_time_usage vocabulary).
create or replace function private.section_of(p_type text) returns text
language sql immutable set search_path = '' as $$
  select case p_type
    when 'video' then 'watch'
    when 'song' then 'listen' when 'story' then 'listen' when 'audiobook' then 'listen'
    else 'games' end
$$;

-- The child's household (or 404). Shared by the three functions below.
create or replace function private.household_of_child(p_user_id uuid, p_child uuid) returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare acc uuid;
begin
  select ch.account_id into acc
  from public.child_profiles ch
  join public.parent_profiles pp on pp.account_id = ch.account_id and pp.user_id = p_user_id
  where ch.id = p_child and ch.status = 'active';
  if acc is null then perform private.fail('KL404', 'NOT_FOUND', 'child'); end if;
  return acc;
end $$;

-- Seconds left today for a limited section (null = no limit).
create or replace function private.screen_time_left(p_child uuid, p_acc uuid, p_section text) returns integer
language plpgsql stable security definer set search_path = '' as $$
declare rules public.screen_time_rules; used integer;
begin
  select * into rules from public.screen_time_rules where child_id = p_child;
  if rules.child_id is null or rules.daily_limit_minutes is null
     or not (p_section = any(rules.limited_sections)) then
    return null;
  end if;
  select coalesce(sum(u.seconds), 0) into used from public.screen_time_usage u
  where u.child_id = p_child and u.local_date = private.local_date(p_acc, now())
    and u.section = any(rules.limited_sections);
  return greatest(0, rules.daily_limit_minutes * 60 - used);
end $$;

create or replace function private.launch(p_user_id uuid, p jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  child uuid; act uuid; acc uuid;
  a public.activities;
  rules public.screen_time_rules;
  age_months integer; section text; left_secs integer;
  plus boolean;
  assets jsonb; resume jsonb;
begin
  begin
    child := (p->>'childId')::uuid; act := (p->>'activityId')::uuid;
  exception when invalid_text_representation then
    perform private.fail('KL400', 'VALIDATION', 'invalid id');
  end;
  if child is null or act is null then perform private.fail('KL400', 'VALIDATION', 'ids are required'); end if;
  acc := private.household_of_child(p_user_id, child);

  -- availability: published only (drafts, in review and retired content never launch)
  select * into a from public.activities where id = act and status = 'published';
  if a.id is null then perform private.fail('KL404', 'NOT_FOUND', 'activity'); end if;

  -- age: the child's age in months must be inside the activity's window
  select (extract(year from age(date_trunc('month', now()), birth_year_month)) * 12
          + extract(month from age(date_trunc('month', now()), birth_year_month)))::int
    into age_months from public.child_profiles where id = child;
  if age_months < a.age_min_months or age_months > a.age_max_months then
    perform private.fail('KL403', 'AGE_NOT_SUITABLE', 'not for this age');
  end if;

  -- parental controls: section switches and blocked categories
  section := private.section_of(a.type);
  select * into rules from public.screen_time_rules where child_id = child;
  if rules.child_id is not null then
    if (section = 'watch' and not rules.watch_enabled) or (section = 'listen' and not rules.listen_enabled) then
      perform private.fail('KL423', 'SECTION_DISABLED', section);
    end if;
    if a.primary_category_id is not null and a.primary_category_id = any(rules.blocked_category_ids) then
      perform private.fail('KL423', 'CATEGORY_BLOCKED', 'category');
    end if;
  end if;

  -- Plus content needs Plus (the Basic free daily allocation comes with the billing module)
  plus := exists (select 1 from public.entitlements e
                  where e.account_id = acc and e.entitlement = 'plus' and e.active_until > now());
  if a.plus_only and not plus then perform private.fail('KL402', 'NEEDS_PLUS', 'plus'); end if;

  -- optional daily limit for this section
  left_secs := private.screen_time_left(child, acc, section);
  if left_secs is not null and left_secs <= 0 then
    perform private.fail('KL423', 'SCREEN_TIME_OVER', section);
  end if;

  -- the files: ready assets only, in role / position order. URLs are signed by the Edge Function.
  select coalesce(jsonb_agg(jsonb_build_object(
           'role', am.role, 'locale', am.locale, 'position', am.position,
           'bucket', m.bucket, 'path', m.object_path, 'kind', m.kind, 'mime', m.mime_type,
           'bytes', m.bytes, 'sha256', m.sha256, 'width', m.width, 'height', m.height,
           'durationMs', m.duration_ms, 'text', am.text) order by am.role, am.position), '[]'::jsonb)
    into assets
  from public.activity_media am join public.media_assets m on m.id = am.asset_id
  where am.activity_id = act and m.status = 'ready';

  -- where this child stopped last time (the newest unfinished session that saved a position)
  select jsonb_build_object('positionMs', (r.metrics->>'positionMs')::int, 'durationMs', (r.metrics->>'durationMs')::int,
                            'page', (r.metrics->>'page')::int, 'pages', (r.metrics->>'pages')::int,
                            'at', s.ended_at)
    into resume
  from public.activity_sessions s join public.activity_results r on r.session_id = s.id
  where s.child_id = child and s.activity_id = act and s.status = 'abandoned'
    and (r.metrics ? 'positionMs' or r.metrics ? 'page')
    and not exists (select 1 from public.activity_sessions s2
                    where s2.child_id = child and s2.activity_id = act and s2.status = 'completed'
                      and s2.ended_at > s.ended_at)
  order by s.ended_at desc limit 1;

  return jsonb_build_object(
    'activityId', a.id, 'type', a.type, 'section', section, 'contentVersion', a.content_version,
    'assets', assets, 'resume', resume, 'remainingSeconds', left_secs);
end $$;

-- POST /play/heartbeat: adds watched / listened seconds to today's usage and says what's left.
create or replace function private.add_screen_time(p_user_id uuid, p_child uuid, p_section text, p_seconds integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare acc uuid; day date; left_secs integer;
begin
  if p_section is null or p_section not in ('games', 'learn', 'watch', 'listen', 'together') then
    perform private.fail('KL400', 'VALIDATION', 'bad section');
  end if;
  if p_seconds is null or p_seconds < 1 or p_seconds > 120 then
    perform private.fail('KL400', 'VALIDATION', 'seconds must be 1..120');
  end if;
  acc := private.household_of_child(p_user_id, p_child);
  day := private.local_date(acc, now());
  insert into public.screen_time_usage (child_id, local_date, section, seconds)
  values (p_child, day, p_section, p_seconds)
  on conflict (child_id, local_date, section)
  do update set seconds = least(86400, public.screen_time_usage.seconds + excluded.seconds), updated_at = now();
  left_secs := private.screen_time_left(p_child, acc, p_section);
  return jsonb_build_object('remainingSeconds', left_secs, 'locked', coalesce(left_secs <= 0, false));
end $$;

-- PUT /children/:id/screen-time: the parent's media controls for one child.
-- p = {dailyLimitMinutes: null | 5..600, limitedSections?: [...], learnEnabled?, watchEnabled?,
--      listenEnabled?, togetherEnabled?, blockedCategoryIds?: [uuid]}
create or replace function private.set_screen_time_rules(p_user_id uuid, p_child uuid, p jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  lim integer; secs text[]; cats uuid[]; row public.screen_time_rules;
begin
  perform private.household_of_child(p_user_id, p_child);
  if jsonb_typeof(p) is distinct from 'object' then perform private.fail('KL400', 'VALIDATION', 'rules are required'); end if;
  if p ? 'dailyLimitMinutes' and jsonb_typeof(p->'dailyLimitMinutes') <> 'null' then
    lim := (p->>'dailyLimitMinutes')::int;
    if lim < 5 or lim > 600 then perform private.fail('KL400', 'VALIDATION', 'daily limit must be 5..600 minutes'); end if;
  end if;
  if p ? 'limitedSections' then
    select array_agg(x) into secs from jsonb_array_elements_text(p->'limitedSections') x;
    if not coalesce(secs, '{}') <@ array['learn','watch','listen','together'] then
      perform private.fail('KL400', 'VALIDATION', 'unknown section');
    end if;
  end if;
  if p ? 'blockedCategoryIds' then
    begin
      select array_agg(x::uuid) into cats from jsonb_array_elements_text(p->'blockedCategoryIds') x;
    exception when invalid_text_representation then
      perform private.fail('KL400', 'VALIDATION', 'invalid category id');
    end;
    if coalesce(cardinality(cats), 0) > 50 then perform private.fail('KL400', 'VALIDATION', 'too many categories'); end if;
    if exists (select 1 from unnest(coalesce(cats, '{}')) c where not exists (select 1 from public.categories k where k.id = c)) then
      perform private.fail('KL400', 'VALIDATION', 'unknown category');
    end if;
  end if;

  insert into public.screen_time_rules as r (child_id, daily_limit_minutes, limited_sections,
      learn_enabled, watch_enabled, listen_enabled, together_enabled, blocked_category_ids)
  values (p_child, lim, coalesce(secs, '{learn,watch,listen,together}'),
      coalesce((p->>'learnEnabled')::boolean, true), coalesce((p->>'watchEnabled')::boolean, true),
      coalesce((p->>'listenEnabled')::boolean, true), coalesce((p->>'togetherEnabled')::boolean, true),
      coalesce(cats, '{}'))
  on conflict (child_id) do update set
      daily_limit_minutes = case when p ? 'dailyLimitMinutes' then lim else r.daily_limit_minutes end,
      limited_sections = coalesce(secs, r.limited_sections),
      learn_enabled = coalesce((p->>'learnEnabled')::boolean, r.learn_enabled),
      watch_enabled = coalesce((p->>'watchEnabled')::boolean, r.watch_enabled),
      listen_enabled = coalesce((p->>'listenEnabled')::boolean, r.listen_enabled),
      together_enabled = coalesce((p->>'togetherEnabled')::boolean, r.together_enabled),
      blocked_category_ids = case when p ? 'blockedCategoryIds' then coalesce(cats, '{}') else r.blocked_category_ids end,
      updated_at = now()
  returning * into row;

  return jsonb_build_object('childId', row.child_id, 'dailyLimitMinutes', row.daily_limit_minutes,
    'limitedSections', to_jsonb(row.limited_sections), 'learnEnabled', row.learn_enabled,
    'watchEnabled', row.watch_enabled, 'listenEnabled', row.listen_enabled,
    'togetherEnabled', row.together_enabled, 'blockedCategoryIds', to_jsonb(row.blocked_category_ids));
end $$;

revoke all on function private.section_of(text) from public, anon, authenticated;
revoke all on function private.household_of_child(uuid, uuid) from public, anon, authenticated;
revoke all on function private.screen_time_left(uuid, uuid, text) from public, anon, authenticated;
revoke all on function private.launch(uuid, jsonb) from public, anon, authenticated;
revoke all on function private.add_screen_time(uuid, uuid, text, integer) from public, anon, authenticated;
revoke all on function private.set_screen_time_rules(uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function private.launch(uuid, jsonb) to service_role;
grant execute on function private.add_screen_time(uuid, uuid, text, integer) to service_role;
grant execute on function private.set_screen_time_rules(uuid, uuid, jsonb) to service_role;
