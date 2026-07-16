begin;

insert into auth.users (id)
values ('00000000-0000-0000-0000-000000000001');

do $test$
declare
  actual_names text[];
begin
  if (select count(*) from public.profiles) <> 1 then
    raise exception 'new Auth user did not receive exactly one profile';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = '00000000-0000-0000-0000-000000000001'
      and timezone = 'UTC'
  ) then
    raise exception 'new profile does not use the UTC default timezone';
  end if;

  select array_agg(name order by sort_order)
  into actual_names
  from public.categories
  where user_id = '00000000-0000-0000-0000-000000000001';

  if actual_names <> array[
    'Health',
    'Work & Learning',
    'Relationships',
    'Personal Growth',
    'Everyday Life'
  ] then
    raise exception 'starter categories are incorrect: %', actual_names;
  end if;

  if has_function_privilege(
    'authenticated', 'public.bootstrap_user(uuid)', 'execute'
  ) then
    raise exception 'authenticated role can execute trusted bootstrap function';
  end if;

  if has_function_privilege(
    'anon', 'public.bootstrap_user(uuid)', 'execute'
  ) then
    raise exception 'anonymous role can execute trusted bootstrap function';
  end if;
end
$test$;

-- Retrying the trusted routine must not duplicate profile or category data.
select public.bootstrap_user('00000000-0000-0000-0000-000000000001');
select public.bootstrap_user('00000000-0000-0000-0000-000000000001');

do $test$
begin
  if (
    select count(*)
    from public.profiles
    where id = '00000000-0000-0000-0000-000000000001'
  ) <> 1 then
    raise exception 'bootstrap retry duplicated the profile';
  end if;

  if (
    select count(*)
    from public.categories
    where user_id = '00000000-0000-0000-0000-000000000001'
  ) <> 5 then
    raise exception 'bootstrap retry duplicated starter categories';
  end if;
end
$test$;

insert into auth.users (id)
values ('00000000-0000-0000-0000-000000000002');

do $test$
begin
  if (select count(*) from public.profiles) <> 2 then
    raise exception 'second user did not receive an independent profile';
  end if;

  if (
    select count(*)
    from public.categories
    where user_id = '00000000-0000-0000-0000-000000000001'
  ) <> 5 then
    raise exception 'second bootstrap changed the first user''s categories';
  end if;

  if (
    select count(*)
    from public.categories
    where user_id = '00000000-0000-0000-0000-000000000002'
  ) <> 5 then
    raise exception 'second user did not receive starter categories';
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
begin
  if (select count(*) from public.profiles) <> 1 then
    raise exception 'RLS did not isolate bootstrapped profiles';
  end if;

  if (select count(*) from public.categories) <> 5 then
    raise exception 'RLS did not isolate bootstrapped categories';
  end if;
end
$test$;

reset role;

delete from auth.users
where id = '00000000-0000-0000-0000-000000000002';

do $test$
begin
  if exists (
    select 1
    from public.profiles
    where id = '00000000-0000-0000-0000-000000000002'
  ) or exists (
    select 1
    from public.categories
    where user_id = '00000000-0000-0000-0000-000000000002'
  ) then
    raise exception 'deleting Auth user did not cascade bootstrap data';
  end if;
end
$test$;

rollback;

