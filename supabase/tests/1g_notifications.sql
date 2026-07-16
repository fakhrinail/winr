begin;

insert into auth.users (id)
values
  ('00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000002');

do $test$
begin
  if (
    select count(*)
    from public.notification_preferences
  ) <> 2 then
    raise exception 'bootstrap did not create one preference per user';
  end if;

  if not exists (
    select 1
    from public.notification_preferences
    where user_id = '00000000-0000-0000-0000-000000000001'
      and log_reminder_enabled = false
      and log_reminder_time = '20:00'
      and weekly_recap_enabled = false
      and monthly_recap_enabled = false
      and recap_time = '07:00'
      and show_win_text_in_notifications = false
  ) then
    raise exception 'notification defaults are incorrect';
  end if;

  if has_table_privilege(
    'anon', 'public.notification_preferences', 'select'
  ) or has_table_privilege(
    'anon', 'public.push_subscriptions', 'select'
  ) or has_table_privilege(
    'anon', 'public.notification_deliveries', 'select'
  ) then
    raise exception 'anonymous role can read notification data';
  end if;

  if has_table_privilege(
    'authenticated', 'public.notification_preferences', 'insert'
  ) or has_table_privilege(
    'authenticated', 'public.notification_preferences', 'delete'
  ) then
    raise exception 'authenticated role can create or delete preferences';
  end if;

  if has_column_privilege(
    'authenticated',
    'public.push_subscriptions',
    'failure_count',
    'update'
  ) then
    raise exception 'authenticated role can update delivery health';
  end if;

  if has_table_privilege(
    'authenticated', 'public.notification_deliveries', 'select'
  ) then
    raise exception 'authenticated role can read server delivery claims';
  end if;
end
$test$;

-- Trusted retries must preserve one preference row and its user choices.
update public.notification_preferences
set log_reminder_enabled = true
where user_id = '00000000-0000-0000-0000-000000000001';

select public.bootstrap_user('00000000-0000-0000-0000-000000000001');

do $test$
begin
  if (
    select count(*)
    from public.notification_preferences
    where user_id = '00000000-0000-0000-0000-000000000001'
  ) <> 1 or not exists (
    select 1
    from public.notification_preferences
    where user_id = '00000000-0000-0000-0000-000000000001'
      and log_reminder_enabled = true
  ) then
    raise exception 'bootstrap retry reset or duplicated preferences';
  end if;
end
$test$;

insert into public.push_subscriptions (
  id, user_id, endpoint, p256dh_key, auth_key, user_agent
)
values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'https://push.example/user-1', 'key-1', 'auth-1', 'iPhone'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'https://push.example/user-2', 'key-2', 'auth-2', 'Mac');

insert into public.notification_deliveries (user_id, type, period_key)
values (
  '00000000-0000-0000-0000-000000000001',
  'log_reminder',
  '2026-07-16'
);

do $test$
begin
  begin
    insert into public.push_subscriptions (
      user_id, endpoint, p256dh_key, auth_key
    ) values (
      '00000000-0000-0000-0000-000000000002',
      'https://push.example/user-1',
      'another-key',
      'another-auth'
    );
    raise exception 'duplicate push endpoint was accepted';
  exception when unique_violation then
    null;
  end;

  begin
    insert into public.notification_deliveries (user_id, type, period_key)
    values (
      '00000000-0000-0000-0000-000000000001',
      'log_reminder',
      '2026-07-16'
    );
    raise exception 'duplicate delivery period was accepted';
  exception when unique_violation then
    null;
  end;

  begin
    update public.notification_preferences
    set log_reminder_time = '20:07'
    where user_id = '00000000-0000-0000-0000-000000000001';
    raise exception 'non-quarter-hour reminder time was accepted';
  exception when check_violation then
    null;
  end;

  begin
    insert into public.notification_deliveries (user_id, type, period_key)
    values (
      '00000000-0000-0000-0000-000000000001',
      'unknown',
      '2026-07-17'
    );
    raise exception 'unknown notification type was accepted';
  exception when check_violation then
    null;
  end;
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
begin
  if (select count(*) from public.notification_preferences) <> 1 then
    raise exception 'RLS did not isolate notification preferences';
  end if;

  if (select count(*) from public.push_subscriptions) <> 1 then
    raise exception 'RLS did not isolate push subscriptions';
  end if;

  update public.notification_preferences
  set
    weekly_recap_enabled = true,
    monthly_recap_enabled = true,
    recap_time = '07:15',
    show_win_text_in_notifications = true
  where user_id = '00000000-0000-0000-0000-000000000001';
  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'user could not update their notification preferences';
  end if;

  update public.notification_preferences
  set weekly_recap_enabled = true
  where user_id = '00000000-0000-0000-0000-000000000002';
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'user updated another user''s preferences';
  end if;

  insert into public.push_subscriptions (
    id, user_id, endpoint, p256dh_key, auth_key, user_agent
  ) values (
    '10000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000001',
    'https://push.example/user-1-ipad',
    'key-3',
    'auth-3',
    'iPad'
  );

  begin
    insert into public.push_subscriptions (
      id, user_id, endpoint, p256dh_key, auth_key
    ) values (
      '10000000-0000-0000-0000-000000000004',
      '00000000-0000-0000-0000-000000000002',
      'https://push.example/not-mine',
      'key-4',
      'auth-4'
    );
    raise exception 'user inserted a subscription for another user';
  exception when insufficient_privilege then
    null;
  end;

  update public.push_subscriptions
  set p256dh_key = 'rotated-key'
  where id = '10000000-0000-0000-0000-000000000001';
  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'user could not rotate their subscription key';
  end if;

  delete from public.push_subscriptions
  where id = '10000000-0000-0000-0000-000000000002';
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'user deleted another user''s subscription';
  end if;
end
$test$;

reset role;
rollback;

