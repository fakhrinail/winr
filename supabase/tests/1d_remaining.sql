begin;

insert into auth.users (id)
values
  ('00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000002');

insert into public.categories (id, user_id, name)
values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Custom Health'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'Custom Health');

insert into public.tags (id, user_id, name)
values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Discipline'),
  ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'Discipline');

insert into public.wins (id, user_id, text, category_id)
values
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'First win', '10000000-0000-0000-0000-000000000001'),
  ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'Second win', '10000000-0000-0000-0000-000000000002');

insert into public.win_assets (
  id, win_id, user_id, storage_path, position, mime_type, byte_size
)
values
  ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'user-1/one.webp', 0, 'image/webp', 100),
  ('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'user-2/one.webp', 0, 'image/webp', 100);

insert into public.win_tags (win_id, tag_id)
values
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001'),
  ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002');

do $test$
begin
  if has_table_privilege('anon', 'public.categories', 'select')
    or has_table_privilege('anon', 'public.tags', 'select')
    or has_table_privilege('anon', 'public.win_assets', 'select')
    or has_table_privilege('anon', 'public.win_tags', 'select') then
    raise exception 'anonymous role can read a protected table';
  end if;

  if has_table_privilege('authenticated', 'public.win_tags', 'update') then
    raise exception 'authenticated role can update win_tags';
  end if;

  if not has_column_privilege(
    'authenticated', 'public.win_assets', 'position', 'update'
  ) then
    raise exception 'authenticated role cannot reorder assets';
  end if;

  if has_column_privilege(
    'authenticated', 'public.win_assets', 'storage_path', 'update'
  ) then
    raise exception 'authenticated role can change an asset storage path';
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
  select count(*) into visible_rows from public.categories;
  if visible_rows <> 6 then
    raise exception 'user can see % categories instead of 6', visible_rows;
  end if;

  select count(*) into visible_rows from public.tags;
  if visible_rows <> 1 then
    raise exception 'user can see % tags instead of 1', visible_rows;
  end if;

  select count(*) into visible_rows from public.win_assets;
  if visible_rows <> 1 then
    raise exception 'user can see % assets instead of 1', visible_rows;
  end if;

  select count(*) into visible_rows from public.win_tags;
  if visible_rows <> 1 then
    raise exception 'user can see % win-tag links instead of 1', visible_rows;
  end if;

  insert into public.categories (id, user_id, name)
  values (
    '10000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000001',
    'Career'
  );

  update public.categories
  set name = 'Work'
  where id = '10000000-0000-0000-0000-000000000003';
  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'user could not update their own category';
  end if;

  update public.categories
  set name = 'Private'
  where id = '10000000-0000-0000-0000-000000000002';
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'user updated another category';
  end if;

  begin
    insert into public.tags (id, user_id, name)
    values (
      '20000000-0000-0000-0000-000000000003',
      '00000000-0000-0000-0000-000000000002',
      'Not mine'
    );
    raise exception 'user inserted a tag for another user';
  exception when insufficient_privilege then
    null;
  end;

  insert into public.tags (id, user_id, name)
  values (
    '20000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000001',
    'First time'
  );

  insert into public.win_tags (win_id, tag_id)
  values (
    '30000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000004'
  );

  begin
    insert into public.win_tags (win_id, tag_id)
    values (
      '30000000-0000-0000-0000-000000000001',
      '20000000-0000-0000-0000-000000000002'
    );
    raise exception 'user attached another user''s tag';
  exception when check_violation or insufficient_privilege then
    null;
  end;

  insert into public.win_assets (
    id, win_id, user_id, storage_path, position, mime_type, byte_size
  ) values (
    '40000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'user-1/two.webp',
    1,
    'image/webp',
    100
  );

  update public.win_assets
  set position = 2
  where id = '40000000-0000-0000-0000-000000000003';
  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'user could not reorder their own asset';
  end if;

  update public.win_assets
  set position = 2
  where id = '40000000-0000-0000-0000-000000000002';
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'user reordered another asset';
  end if;

  delete from public.win_tags
  where win_id = '30000000-0000-0000-0000-000000000001'
    and tag_id = '20000000-0000-0000-0000-000000000004';
  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'user could not detach their own tag';
  end if;

  delete from public.categories
  where id = '10000000-0000-0000-0000-000000000003';
  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'user could not delete their own category';
  end if;
end
$test$;

reset role;
rollback;
