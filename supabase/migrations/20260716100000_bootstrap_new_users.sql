-- Create the minimum Winr application data required by every Auth user.

create function public.bootstrap_user(target_user_id uuid)
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
end;
$$;

revoke all on function public.bootstrap_user(uuid)
from public, anon, authenticated;

create function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.bootstrap_user(new.id);
  return new;
end;
$$;

revoke all on function public.handle_new_auth_user()
from public, anon, authenticated;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

