-- Profile authorization reference implementation (checkpoint 1D).
-- Profile creation is reserved for the trusted auth bootstrap in checkpoint 1F.

alter table public.profiles enable row level security;

revoke all on table public.profiles from anon, authenticated;

grant select on table public.profiles to authenticated;

grant update (timezone, onboarding_completed_at)
on table public.profiles
to authenticated;

create policy profiles_select_own
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

create policy profiles_update_own
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

