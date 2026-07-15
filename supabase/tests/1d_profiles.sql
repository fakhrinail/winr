begin;

insert into auth.users (id)
values
  ('00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000002');

insert into public.profiles (id, timezone)
values
  ('00000000-0000-0000-0000-000000000001', 'Asia/Jakarta'),
  ('00000000-0000-0000-0000-000000000002', 'UTC');

do $test$
begin
  if has_table_privilege('anon', 'public.profiles', 'select') then
    raise exception 'anonymous role can select profiles';
  end if;

  if not has_table_privilege('authenticated', 'public.profiles', 'select') then
    raise exception 'authenticated role cannot select profiles';
  end if;

  if has_table_privilege('authenticated', 'public.profiles', 'insert') then
    raise exception 'authenticated role can insert profiles';
  end if;

  if has_table_privilege('authenticated', 'public.profiles', 'delete') then
    raise exception 'authenticated role can delete profiles';
  end if;

  if not has_column_privilege(
    'authenticated',
    'public.profiles',
    'timezone',
    'update'
  ) then
    raise exception 'authenticated role cannot update profile timezone';
  end if;

  if has_column_privilege(
    'authenticated',
    'public.profiles',
    'created_at',
    'update'
  ) then
    raise exception 'authenticated role can update protected profile columns';
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
  from public.profiles;

  if visible_rows <> 1 then
    raise exception 'user can see % profiles instead of 1', visible_rows;
  end if;

  update public.profiles
  set timezone = 'Asia/Singapore'
  where id = '00000000-0000-0000-0000-000000000001';

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'user could not update their own profile';
  end if;

  update public.profiles
  set timezone = 'Asia/Singapore'
  where id = '00000000-0000-0000-0000-000000000002';

  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'user updated another profile';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = '00000000-0000-0000-0000-000000000001'
      and timezone = 'Asia/Singapore'
      and updated_at > created_at
  ) then
    raise exception 'own profile update or updated_at trigger failed';
  end if;
end
$test$;

reset role;
rollback;

