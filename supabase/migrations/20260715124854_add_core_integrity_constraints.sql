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