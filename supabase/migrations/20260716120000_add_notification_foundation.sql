-- Notification preferences, browser subscriptions, and delivery deduplication.
-- Actual Web Push delivery and scheduling are implemented after the PWA exists.

create table public.notification_preferences (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  log_reminder_enabled boolean not null default false,
  log_reminder_time time without time zone not null default '20:00',
  weekly_recap_enabled boolean not null default false,
  monthly_recap_enabled boolean not null default false,
  recap_time time without time zone not null default '07:00',
  show_win_text_in_notifications boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notification_preferences_log_time_quarter_hour check (
    extract(second from log_reminder_time) = 0
    and mod(extract(minute from log_reminder_time)::integer, 15) = 0
  ),
  constraint notification_preferences_recap_time_quarter_hour check (
    extract(second from recap_time) = 0
    and mod(extract(minute from recap_time)::integer, 15) = 0
  )
);

create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  endpoint text not null,
  p256dh_key text not null,
  auth_key text not null,
  user_agent text,
  failure_count integer not null default 0,
  last_success_at timestamptz,
  disabled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint push_subscriptions_endpoint_not_blank check (
    length(trim(endpoint)) > 0
  ),
  constraint push_subscriptions_p256dh_key_not_blank check (
    length(trim(p256dh_key)) > 0
  ),
  constraint push_subscriptions_auth_key_not_blank check (
    length(trim(auth_key)) > 0
  ),
  constraint push_subscriptions_failure_count_non_negative check (
    failure_count >= 0
  ),
  constraint push_subscriptions_endpoint_unique unique (endpoint)
);

create table public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null,
  period_key date not null,
  attempted_at timestamptz not null default now(),
  constraint notification_deliveries_type_valid check (
    type in ('log_reminder', 'weekly_recap', 'monthly_recap')
  ),
  constraint notification_deliveries_period_unique unique (
    user_id,
    type,
    period_key
  )
);

create index push_subscriptions_user_active_idx
on public.push_subscriptions (user_id, created_at, id)
where disabled_at is null;

create index notification_deliveries_user_attempted_idx
on public.notification_deliveries (user_id, attempted_at desc);

create trigger notification_preferences_set_updated_at
before update on public.notification_preferences
for each row execute function public.set_updated_at();

create trigger push_subscriptions_set_updated_at
before update on public.push_subscriptions
for each row execute function public.set_updated_at();

create trigger push_subscriptions_prevent_user_id_change
before update of user_id on public.push_subscriptions
for each row execute function public.prevent_user_id_change();

alter table public.notification_preferences enable row level security;
alter table public.push_subscriptions enable row level security;
alter table public.notification_deliveries enable row level security;

revoke all on table public.notification_preferences from anon, authenticated;
revoke all on table public.push_subscriptions from anon, authenticated;
revoke all on table public.notification_deliveries from anon, authenticated;

grant select on table public.notification_preferences to authenticated;
grant update (
  log_reminder_enabled,
  log_reminder_time,
  weekly_recap_enabled,
  monthly_recap_enabled,
  recap_time,
  show_win_text_in_notifications
)
on table public.notification_preferences
to authenticated;

create policy notification_preferences_select_own
on public.notification_preferences for select to authenticated
using ((select auth.uid()) = user_id);

create policy notification_preferences_update_own
on public.notification_preferences for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

grant select, delete on table public.push_subscriptions to authenticated;
grant insert (
  id,
  user_id,
  endpoint,
  p256dh_key,
  auth_key,
  user_agent
)
on table public.push_subscriptions
to authenticated;
grant update (p256dh_key, auth_key, user_agent)
on table public.push_subscriptions
to authenticated;

create policy push_subscriptions_select_own
on public.push_subscriptions for select to authenticated
using ((select auth.uid()) = user_id);

create policy push_subscriptions_insert_own
on public.push_subscriptions for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy push_subscriptions_update_own
on public.push_subscriptions for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy push_subscriptions_delete_own
on public.push_subscriptions for delete to authenticated
using ((select auth.uid()) = user_id);

-- Backfill preferences for users created before this migration.
insert into public.notification_preferences (user_id)
select id from public.profiles
on conflict (user_id) do nothing;

-- Extend the trusted bootstrap for all future Auth users and safe retries.
create or replace function public.bootstrap_user(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, timezone)
  values (target_user_id, 'UTC')
  on conflict (id) do nothing;

  insert into public.categories (user_id, name, color, sort_order)
  values
    (target_user_id, 'Health', '#65A30D', 10),
    (target_user_id, 'Work & Learning', '#2563EB', 20),
    (target_user_id, 'Relationships', '#DB2777', 30),
    (target_user_id, 'Personal Growth', '#7C3AED', 40),
    (target_user_id, 'Everyday Life', '#D97706', 50)
  on conflict do nothing;

  insert into public.notification_preferences (user_id)
  values (target_user_id)
  on conflict (user_id) do nothing;
end;
$$;

revoke all on function public.bootstrap_user(uuid)
from public, anon, authenticated;

