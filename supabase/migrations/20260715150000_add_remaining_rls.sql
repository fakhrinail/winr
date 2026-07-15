-- Remaining application-table authorization (checkpoint 1D).

alter table public.categories enable row level security;
alter table public.tags enable row level security;
alter table public.win_assets enable row level security;
alter table public.win_tags enable row level security;

revoke all on table public.categories from anon, authenticated;
revoke all on table public.tags from anon, authenticated;
revoke all on table public.win_assets from anon, authenticated;
revoke all on table public.win_tags from anon, authenticated;

grant select, delete on table public.categories to authenticated;
grant insert (id, user_id, name, color, sort_order, archived_at)
on table public.categories to authenticated;
grant update (name, color, sort_order, archived_at)
on table public.categories to authenticated;

create policy categories_select_own
on public.categories for select to authenticated
using ((select auth.uid()) = user_id);

create policy categories_insert_own
on public.categories for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy categories_update_own
on public.categories for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy categories_delete_own
on public.categories for delete to authenticated
using ((select auth.uid()) = user_id);

grant select, delete on table public.tags to authenticated;
grant insert (id, user_id, name, color, archived_at)
on table public.tags to authenticated;
grant update (name, color, archived_at)
on table public.tags to authenticated;

create policy tags_select_own
on public.tags for select to authenticated
using ((select auth.uid()) = user_id);

create policy tags_insert_own
on public.tags for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy tags_update_own
on public.tags for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy tags_delete_own
on public.tags for delete to authenticated
using ((select auth.uid()) = user_id);

grant select, delete on table public.win_assets to authenticated;
grant insert (
  id,
  win_id,
  user_id,
  storage_path,
  position,
  mime_type,
  width,
  height,
  byte_size
)
on table public.win_assets to authenticated;
grant update (position)
on table public.win_assets to authenticated;

create policy win_assets_select_own
on public.win_assets for select to authenticated
using ((select auth.uid()) = user_id);

create policy win_assets_insert_own
on public.win_assets for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy win_assets_update_own
on public.win_assets for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy win_assets_delete_own
on public.win_assets for delete to authenticated
using ((select auth.uid()) = user_id);

-- win_tags derives ownership through both linked records. Updating a link is
-- intentionally unsupported; clients detach it and attach a new one instead.
grant select, insert, delete on table public.win_tags to authenticated;

create policy win_tags_select_own
on public.win_tags for select to authenticated
using (
  exists (
    select 1
    from public.wins
    where wins.id = win_tags.win_id
      and wins.user_id = (select auth.uid())
  )
);

create policy win_tags_insert_own
on public.win_tags for insert to authenticated
with check (
  exists (
    select 1
    from public.wins
    where wins.id = win_tags.win_id
      and wins.user_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.tags
    where tags.id = win_tags.tag_id
      and tags.user_id = (select auth.uid())
  )
);

create policy win_tags_delete_own
on public.win_tags for delete to authenticated
using (
  exists (
    select 1
    from public.wins
    where wins.id = win_tags.win_id
      and wins.user_id = (select auth.uid())
  )
);

