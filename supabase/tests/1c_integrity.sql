begin;

insert into auth.users (id)
values
  ('00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000002');

insert into public.profiles (id)
values
  ('00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000002');

insert into public.categories (id, user_id, name)
values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Health'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'Health');

insert into public.tags (id, user_id, name)
values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Discipline'),
  ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'Discipline');

insert into public.wins (id, user_id, text, category_id)
values
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'First win', '10000000-0000-0000-0000-000000000001'),
  ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'Second win', '10000000-0000-0000-0000-000000000002');

do $test$
begin
  begin
    insert into public.wins (id, user_id, text)
    values (
      '30000000-0000-0000-0000-000000000003',
      '00000000-0000-0000-0000-000000000001',
      '   '
    );
    raise exception 'blank win text was accepted';
  exception when check_violation then
    null;
  end;

  begin
    insert into public.categories (user_id, name)
    values ('00000000-0000-0000-0000-000000000001', ' health ');
    raise exception 'normalized category duplicate was accepted';
  exception when unique_violation then
    null;
  end;

  begin
    update public.wins
    set category_id = '10000000-0000-0000-0000-000000000002'
    where id = '30000000-0000-0000-0000-000000000001';
    raise exception 'cross-owner category was accepted';
  exception when check_violation then
    null;
  end;

  begin
    update public.wins
    set user_id = '00000000-0000-0000-0000-000000000002'
    where id = '30000000-0000-0000-0000-000000000001';
    raise exception 'win ownership change was accepted';
  exception when check_violation then
    null;
  end;

  begin
    insert into public.win_tags (win_id, tag_id)
    values ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002');
    raise exception 'cross-owner tag was accepted';
  exception when check_violation then
    null;
  end;

  begin
    insert into public.win_assets (
      id, win_id, user_id, storage_path, position, mime_type, byte_size
    ) values (
      '40000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000002',
      'wrong-owner.webp',
      0,
      'image/webp',
      100
    );
    raise exception 'cross-owner asset was accepted';
  exception when check_violation then
    null;
  end;

  begin
    insert into public.win_assets (
      win_id, user_id, storage_path, position, mime_type, byte_size
    ) values (
      '30000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      'negative-position.webp',
      -1,
      'image/webp',
      100
    );
    raise exception 'negative asset position was accepted';
  exception when check_violation then
    null;
  end;
end
$test$;

insert into public.win_assets (
  id, win_id, user_id, storage_path, position, mime_type, byte_size
) values (
  '40000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'one.webp',
  0,
  'image/webp',
  100
);

do $test$
begin
  begin
    insert into public.win_assets (
      win_id, user_id, storage_path, position, mime_type, byte_size
    ) values (
      '30000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      'two.webp',
      0,
      'image/webp',
      100
    );
    raise exception 'duplicate asset position was accepted';
  exception when unique_violation then
    null;
  end;

  begin
    insert into public.win_assets (
      win_id, user_id, storage_path, position, mime_type, byte_size
    ) values (
      '30000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      'one.webp',
      1,
      'image/webp',
      100
    );
    raise exception 'duplicate storage path was accepted';
  exception when unique_violation then
    null;
  end;
end
$test$;

select pg_sleep(0.01);

update public.wins
set text = 'Updated win'
where id = '30000000-0000-0000-0000-000000000001';

do $test$
begin
  if not (
    select updated_at > created_at
    from public.wins
    where id = '30000000-0000-0000-0000-000000000001'
  ) then
    raise exception 'updated_at was not advanced';
  end if;
end
$test$;

insert into public.win_tags (win_id, tag_id)
values ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001');

delete from public.categories
where id = '10000000-0000-0000-0000-000000000001';

do $test$
begin
  if (
    select category_id is not null
    from public.wins
    where id = '30000000-0000-0000-0000-000000000001'
  ) then
    raise exception 'category deletion did not uncategorize win';
  end if;
end
$test$;

delete from public.tags
where id = '20000000-0000-0000-0000-000000000001';

do $test$
begin
  if exists (
    select 1
    from public.win_tags
    where win_id = '30000000-0000-0000-0000-000000000001'
  ) then
    raise exception 'tag deletion did not remove win_tags';
  end if;
end
$test$;

delete from public.wins
where id = '30000000-0000-0000-0000-000000000001';

do $test$
begin
  if exists (
    select 1
    from public.win_assets
    where win_id = '30000000-0000-0000-0000-000000000001'
  ) then
    raise exception 'win deletion did not remove assets';
  end if;
end
$test$;

rollback;
