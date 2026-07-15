begin;

insert into auth.users (id)
values
  ('00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000002');

insert into public.profiles (id, timezone)
values
  ('00000000-0000-0000-0000-000000000001', 'Asia/Jakarta'),
  ('00000000-0000-0000-0000-000000000002', 'UTC');

insert into public.wins (id, text, user_id)
values
  ('00000000-0000-0000-0000-000000000001', 'Test', '00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000002', 'Test', '00000000-0000-0000-0000-000000000002');

do $test$
begin
  if has_table_privilege('anon', 'public.wins', 'select') then
    raise exception 'anonymous role can select wins';
  end if;

  if not has_table_privilege('authenticated', 'public.wins', 'select') then
    raise exception 'authenticated role cannot select wins';
  end if;

  if not has_column_privilege('authenticated', 'public.wins', 'text', 'insert') then
    raise exception 'authenticated role cannot insert wins';
  end if;

  if has_column_privilege(
    'authenticated',
    'public.wins',
    'created_at',
    'insert'
  ) then
    raise exception 'authenticated role can set created_at';
  end if;

  if not has_table_privilege('authenticated', 'public.wins', 'delete') then
    raise exception 'authenticated role cannot delete wins';
  end if;

  if not has_column_privilege(
    'authenticated',
    'public.wins',
    'text',
    'update'
  ) then
    raise exception 'authenticated role cannot update win text';
  end if;

  if not has_column_privilege(
    'authenticated',
    'public.wins',
    'category_id',
    'update'
  ) then
    raise exception 'authenticated role cannot update win category_id';
  end if;

  if not has_column_privilege(
    'authenticated',
    'public.wins',
    'occurred_at',
    'update'
  ) then
    raise exception 'authenticated role cannot update win occurred_at';
  end if;

  if has_column_privilege(
    'authenticated',
    'public.wins',
    'user_id',
    'update'
  ) then
    raise exception 'authenticated role can update protected user_id columns';
  end if;
end
$test$;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000001',
  true
);

do $test$
declare
  affected_rows integer;
  visible_rows integer;
begin
  select count(*)
  into visible_rows
  from public.wins;

  if visible_rows <> 1 then
    raise exception 'user can see % wins instead of 1', visible_rows;
  end if;

  insert into public.wins (id, text, user_id)
  values ('00000000-0000-0000-0000-000000000003', 'Test', '00000000-0000-0000-0000-000000000001');

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'user could not insert their own win';
  end if;

  begin
  insert into public.wins (id, text, user_id)
  values (
    '00000000-0000-0000-0000-000000000004',
    'Test',
    '00000000-0000-0000-0000-000000000002'
  );

  raise exception 'user inserted a win for another user';
exception
  when insufficient_privilege then
    null;
  end;

  update public.wins
  set text = 'Updated Test'
  where id = '00000000-0000-0000-0000-000000000001';

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'user could not update their own win';
  end if;

  update public.wins
  set text = 'Updated Test'
  where id = '00000000-0000-0000-0000-000000000002';

  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'user updated another win';
  end if;

  if not exists (
    select 1
    from public.wins
    where id = '00000000-0000-0000-0000-000000000001'
      and text = 'Updated Test'
      and updated_at > created_at
  ) then
    raise exception 'own win update or updated_at trigger failed';
  end if;

  delete from public.wins
  where id = '00000000-0000-0000-0000-000000000001';

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'user could not delete their own win';
  end if;

  delete from public.wins
  where id = '00000000-0000-0000-0000-000000000002';

  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'user could delete another users win';
  end if;
end
$test$;

reset role;
rollback;
