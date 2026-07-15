-- Win authorization reference implementation (checkpoint 1D).

alter table public.wins enable row level security;

revoke all on table public.wins from anon, authenticated;

grant select, delete 
on table public.wins 
to authenticated;

grant insert (id, user_id, text, category_id, occurred_at)
on table public.wins
to authenticated;

grant update (occurred_at, text, category_id)
on table public.wins
to authenticated;

create policy wins_insert_own
on public.wins
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy wins_select_own
on public.wins
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy wins_update_own
on public.wins
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy wins_delete_own
on public.wins
for delete
to authenticated
using ((select auth.uid()) = user_id);

