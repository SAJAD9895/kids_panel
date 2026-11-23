-- PATCH /children/:id: edit a child profile (Phase 7, needed by the Flutter app's child management).
-- Same pattern as the other family operations (0012): service-only, p_user_id is always the
-- verified JWT's `sub`, the function re-checks membership itself, errors are KL4xx.
--
-- c = any subset of {nickname, birthYearMonth, avatarId, stage, contentLocale}.
--   "avatarId": null clears the buddy; a key that is absent leaves the column unchanged.
-- Any adult of the household (owner or co_parent) may edit. Deleting stays owner-only (0012).
-- Returns the edited child in the API's shape (camelCase), so the client needs no second read.

create or replace function private.update_child(p_user_id uuid, p_child_id uuid, c jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare acc uuid; av uuid; r public.child_profiles;
begin
  if jsonb_typeof(c) is distinct from 'object' then
    perform private.fail('KL400', 'VALIDATION', 'body must be an object');
  end if;
  if exists (select 1 from jsonb_object_keys(c) k
             where k not in ('nickname', 'birthYearMonth', 'avatarId', 'stage', 'contentLocale')) then
    perform private.fail('KL400', 'VALIDATION', 'unknown field');
  end if;

  -- membership: the child must belong to the caller's household (404 otherwise, so ids can't be probed)
  select ch.account_id into acc
  from public.child_profiles ch
  join public.parent_profiles pp on pp.account_id = ch.account_id and pp.user_id = p_user_id
  where ch.id = p_child_id;
  if acc is null then perform private.fail('KL404', 'NOT_FOUND', 'child'); end if;

  if c ? 'avatarId' and nullif(c->>'avatarId', '') is not null then
    select id into av from public.avatars where id = (c->>'avatarId')::uuid and active;
    if av is null then perform private.fail('KL400', 'VALIDATION', 'unknown avatar'); end if;
  end if;

  update public.child_profiles set
    nickname         = case when c ? 'nickname' then btrim(c->>'nickname') else nickname end,
    birth_year_month = case when c ? 'birthYearMonth' then private.parse_birth_year_month(c->>'birthYearMonth')
                            else birth_year_month end,
    avatar_id        = case when c ? 'avatarId' then av else avatar_id end,
    learning_stage   = case when c ? 'stage' then coalesce(nullif(c->>'stage', ''), 'auto') else learning_stage end,
    content_locale   = case when c ? 'contentLocale' then nullif(c->>'contentLocale', '') else content_locale end
  where id = p_child_id
  returning * into r;

  return jsonb_build_object(
    'id', r.id, 'nickname', r.nickname, 'avatarId', r.avatar_id,
    'birthYearMonth', to_char(r.birth_year_month, 'YYYY-MM'),
    'stage', r.learning_stage, 'contentLocale', r.content_locale, 'status', r.status, 'sort', r.sort);
exception
  when check_violation or not_null_violation then
    perform private.fail('KL400', 'VALIDATION', 'invalid child: ' || sqlerrm);
    return null;
  when invalid_text_representation then
    perform private.fail('KL400', 'VALIDATION', 'invalid id');
    return null;
end $$;

revoke all on function private.update_child(uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function private.update_child(uuid, uuid, jsonb) to service_role;
