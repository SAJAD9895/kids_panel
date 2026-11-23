-- =============================================================================
-- C1 private.update_child (migration 0014): PATCH /children/:id
-- Called as the Edge Function calls it (service connection, user id from the JWT).
-- =============================================================================
\set ON_ERROR_STOP on
begin;

do $$
declare
  alice uuid := '00000000-0000-4000-a000-0000000000a1';
  bob   uuid := '00000000-0000-4000-a000-0000000000b1';
  mia uuid; buddy uuid; r jsonb; before public.child_profiles;
begin
  select id into mia from child_profiles where nickname = 'Mia';
  select id into buddy from avatars where key = 'buddy-01';
  select * into before from child_profiles where id = mia;

  -- partial update: only the named fields change
  r := private.update_child(alice, mia, jsonb_build_object('nickname', '  Mimi ', 'avatarId', buddy));
  if r->>'nickname' <> 'Mimi' or (r->>'avatarId')::uuid <> buddy then raise exception 'C1 FAIL: edit %', r; end if;
  if (select birth_year_month from child_profiles where id = mia) <> before.birth_year_month then
    raise exception 'C1 FAIL: untouched field changed'; end if;
  if r->>'birthYearMonth' !~ '^\d{4}-\d{2}$' then raise exception 'C1 FAIL: birthYearMonth shape %', r; end if;

  -- avatarId null clears the buddy
  r := private.update_child(alice, mia, '{"avatarId": null}');
  if r->'avatarId' <> 'null'::jsonb then raise exception 'C1 FAIL: avatar not cleared'; end if;

  -- another family gets 404, and nothing changes
  begin perform private.update_child(bob, mia, '{"nickname":"Hacked"}');
        raise exception 'C1 FAIL: Bob edited Mia';
  exception when sqlstate 'KL404' then null; end;
  if (select nickname from child_profiles where id = mia) <> 'Mimi' then raise exception 'C1 FAIL: cross-family write'; end if;

  -- validation
  begin perform private.update_child(alice, mia, '{"nickname":""}');
        raise exception 'C1 FAIL: empty nickname';
  exception when sqlstate 'KL400' then null; end;
  begin perform private.update_child(alice, mia, '{"nickname":"abcdefghijklmnopqrstu"}');
        raise exception 'C1 FAIL: 21-character nickname';
  exception when sqlstate 'KL400' then null; end;
  begin perform private.update_child(alice, mia, '{"birthYearMonth":"1990-01"}');
        raise exception 'C1 FAIL: adult birth date';
  exception when sqlstate 'KL400' then null; end;
  begin perform private.update_child(alice, mia, jsonb_build_object('avatarId', gen_random_uuid()));
        raise exception 'C1 FAIL: unknown avatar';
  exception when sqlstate 'KL400' then null; end;
  begin perform private.update_child(alice, mia, '{"accountId":"00000000-0000-4000-a000-0000000000b1"}');
        raise exception 'C1 FAIL: unknown field accepted (account move)';
  exception when sqlstate 'KL400' then null; end;
  begin perform private.update_child(alice, mia, '{"stage":"wizard"}');
        raise exception 'C1 FAIL: bad stage';
  exception when sqlstate 'KL400' then null; end;

  raise notice 'C1 ok: child edit is partial, validated, household-only (404 across families)';
end $$;

-- clients can't call it
set local role authenticated;
do $$ begin
  perform private.update_child('00000000-0000-4000-a000-0000000000a1', gen_random_uuid(), '{}');
  raise exception 'C1 FAIL: authenticated can execute update_child';
exception when insufficient_privilege then
  raise notice 'C1 ok: update_child is service-only';
end $$;
reset role;

rollback;
