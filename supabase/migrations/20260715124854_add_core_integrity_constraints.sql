alter table public.wins
  add constraint wins_text_not_blank
  check (length(trim(text)) > 0);

alter table public.categories
  add constraint categories_name_not_blank
  check (length(trim(name)) > 0);

alter table public.tags
  add constraint tags_name_not_blank
  check (length(trim(name)) > 0);

alter table public.win_assets
  add constraint win_assets_storage_path_not_blank
    check (length(trim(storage_path)) > 0),
  add constraint win_assets_mime_type_not_blank
    check (length(trim(mime_type)) > 0),
  add constraint win_assets_width_positive
    check (width is null or width > 0),
  add constraint win_assets_height_positive
    check (height is null or height > 0),
  add constraint win_assets_byte_size_positive
    check (byte_size > 0),
  add constraint win_assets_position_non_negative
    check (position >= 0);

create unique index categories_user_name_unique
  on public.categories (user_id, lower(trim(name)));

create unique index tags_user_name_unique
  on public.tags (user_id, lower(trim(name)));

-- A photo's position is stable within its win, and every stored object path is
-- globally unique. Both rules also make retries safe to reason about.
create unique index win_assets_win_position_unique
  on public.win_assets (win_id, position);

create unique index win_assets_storage_path_unique
  on public.win_assets (storage_path);

-- Query indexes for the v1 timeline, category filters, tag filters, category
-- picker, and per-user asset usage. Primary-key indexes already cover lookups
-- beginning with win_tags.win_id and win_assets.id.
create index wins_user_occurred_at_idx
  on public.wins (user_id, occurred_at desc, id desc);

create index wins_user_category_occurred_at_idx
  on public.wins (user_id, category_id, occurred_at desc, id desc)
  where category_id is not null;

create index win_tags_tag_win_idx
  on public.win_tags (tag_id, win_id);

create index categories_user_active_sort_idx
  on public.categories (user_id, sort_order, id)
  where archived_at is null;

create index win_assets_user_created_at_idx
  on public.win_assets (user_id, created_at, id);

-- Ownership is permanent. Moving a record between accounts would complicate
-- authorization and could invalidate related rows.
create function public.prevent_user_id_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.user_id is distinct from old.user_id then
    raise exception using
      errcode = '23514',
      message = 'user_id cannot be changed';
  end if;

  return new;
end;
$$;

create trigger categories_prevent_user_id_change
before update of user_id on public.categories
for each row execute function public.prevent_user_id_change();

create trigger tags_prevent_user_id_change
before update of user_id on public.tags
for each row execute function public.prevent_user_id_change();

create trigger wins_prevent_user_id_change
before update of user_id on public.wins
for each row execute function public.prevent_user_id_change();

create trigger win_assets_prevent_user_id_change
before update of user_id on public.win_assets
for each row execute function public.prevent_user_id_change();

-- Cross-table checks prevent a user from associating their win with another
-- user's category, tag, or asset metadata. RLS in checkpoint 1D will add the
-- external authorization boundary; these checks preserve internal integrity.
create function public.check_win_category_owner()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.category_id is not null and not exists (
    select 1
    from public.categories
    where id = new.category_id
      and user_id = new.user_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'win and category must belong to the same user',
      constraint = 'wins_category_owner_matches';
  end if;

  return new;
end;
$$;

create trigger wins_check_category_owner
before insert or update of user_id, category_id on public.wins
for each row execute function public.check_win_category_owner();

create function public.check_win_tag_owner()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.wins as wins
    join public.tags as tags on tags.id = new.tag_id
    where wins.id = new.win_id
      and wins.user_id = tags.user_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'win and tag must belong to the same user',
      constraint = 'win_tags_owner_matches';
  end if;

  return new;
end;
$$;

create trigger win_tags_check_owner
before insert or update of win_id, tag_id on public.win_tags
for each row execute function public.check_win_tag_owner();

create function public.check_win_asset_owner()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.wins
    where id = new.win_id
      and user_id = new.user_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'win and asset must belong to the same user',
      constraint = 'win_assets_owner_matches';
  end if;

  return new;
end;
$$;

create trigger win_assets_check_owner
before insert or update of win_id, user_id on public.win_assets
for each row execute function public.check_win_asset_owner();

-- Keep updated_at trustworthy without requiring every client to remember it.
create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = clock_timestamp();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger categories_set_updated_at
before update on public.categories
for each row execute function public.set_updated_at();

create trigger tags_set_updated_at
before update on public.tags
for each row execute function public.set_updated_at();

create trigger wins_set_updated_at
before update on public.wins
for each row execute function public.set_updated_at();

create trigger win_assets_set_updated_at
before update on public.win_assets
for each row execute function public.set_updated_at();
