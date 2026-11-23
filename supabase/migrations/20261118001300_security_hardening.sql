-- Security hardening found by the backend verification (docs/backend/backend-test-report.md).
-- Kids Learning Platform · Phase 6, 2026-11-18.

-- F1: private.local_date(account, ts) returns any household's calendar day (and so reveals its
-- timezone) and was executable by every role. No policy uses it; only server code does.
revoke all on function private.local_date(uuid, timestamptz) from public, anon, authenticated;
grant execute on function private.local_date(uuid, timestamptz) to service_role;

-- F2: review bypass. The draft's guard_publish only checked the moment a row BECAME published, so
-- an editor (content.write, no content.publish) could change a live activity's title, a live game's
-- config, a live quiz's answers or a live row's items, and children saw it at once with no review.
-- Now any insert / update / delete that touches LIVE content, or a child row of live content,
-- needs content.publish (or the service role). Drafts stay freely editable by editors.
-- Live = published (activities, courses, collections, learning paths, categories), active (rewards,
-- reward sets, avatars) or ready (media assets); child rows are live when their parent is.
create or replace function private.is_live(tbl text, r jsonb) returns boolean
language sql stable security definer set search_path = '' as $$
  select case tbl
    when 'activities'     then r->>'status' = 'published'
    when 'courses'        then r->>'status' = 'published'
    when 'collections'    then r->>'status' = 'published'
    when 'learning_paths' then r->>'status' = 'published'
    when 'categories'     then r->>'status' = 'published'
    when 'rewards'        then r->>'status' = 'active'
    when 'reward_sets'    then coalesce((r->>'active')::boolean, false)
    when 'avatars'        then coalesce((r->>'active')::boolean, false)
    when 'media_assets'   then r->>'status' = 'ready'
    when 'games'               then exists (select 1 from public.activities a where a.id = (r->>'activity_id')::uuid and a.status = 'published')
    when 'questions'           then exists (select 1 from public.activities a where a.id = (r->>'activity_id')::uuid and a.status = 'published')
    when 'activity_media'      then exists (select 1 from public.activities a where a.id = (r->>'activity_id')::uuid and a.status = 'published')
    when 'activity_skills'     then exists (select 1 from public.activities a where a.id = (r->>'activity_id')::uuid and a.status = 'published')
    when 'activity_categories' then exists (select 1 from public.activities a where a.id = (r->>'activity_id')::uuid and a.status = 'published')
    when 'answers' then exists (select 1 from public.questions q join public.activities a on a.id = q.activity_id
                                where q.id = (r->>'question_id')::uuid and a.status = 'published')
    when 'course_modules' then exists (select 1 from public.courses c where c.id = (r->>'course_id')::uuid and c.status = 'published')
    when 'lessons' then exists (select 1 from public.course_modules m join public.courses c on c.id = m.course_id
                                where m.id = (r->>'module_id')::uuid and c.status = 'published')
    when 'lesson_steps' then exists (select 1 from public.lessons l join public.course_modules m on m.id = l.module_id
                                     join public.courses c on c.id = m.course_id
                                     where l.id = (r->>'lesson_id')::uuid and c.status = 'published')
    when 'collection_items' then exists (select 1 from public.collections c where c.id = (r->>'collection_id')::uuid and c.status = 'published')
    when 'learning_path_courses' then exists (select 1 from public.learning_paths p where p.id = (r->>'path_id')::uuid and p.status = 'published')
    else false end;
$$;

-- INVOKER on purpose (is_service() must see the real caller, see helpers_triggers).
create or replace function private.guard_live_content() returns trigger
language plpgsql set search_path = public as $$
begin
  if private.is_service() or private.has_permission('content.publish') then
    return coalesce(new, old);
  end if;
  if (tg_op <> 'INSERT' and private.is_live(tg_table_name, to_jsonb(old)))
     or (tg_op <> 'DELETE' and private.is_live(tg_table_name, to_jsonb(new))) then
    raise exception 'content.publish permission required to change live content (%)', tg_table_name
      using errcode = '42501';
  end if;
  return coalesce(new, old);
end $$;

drop trigger if exists guard_publish on activities;
drop trigger if exists guard_publish on courses;
drop trigger if exists guard_publish on collections;
drop trigger if exists guard_publish on learning_paths;

do $$
declare t text;
begin
  foreach t in array array[
    'activities','courses','collections','learning_paths','categories','rewards','reward_sets','avatars',
    'media_assets','games','questions','answers','activity_media','activity_skills','activity_categories',
    'course_modules','lessons','lesson_steps','collection_items','learning_path_courses']
  loop
    execute format('create trigger guard_live before insert or update or delete on public.%I
                    for each row execute function private.guard_live_content()', t);
  end loop;
end $$;
