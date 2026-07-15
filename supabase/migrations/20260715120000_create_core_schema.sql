-- Winr core schema (checkpoint 1B).
-- Validation, indexes, RLS, Storage policies, and bootstrap automation are
-- deliberately added in later checkpoints so each layer can be reviewed alone.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  timezone text,
  onboarding_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  color text,
  sort_order integer not null default 0,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  color text,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.wins (
  id uuid primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  text text not null,
  category_id uuid references public.categories (id) on delete set null,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.win_tags (
  win_id uuid not null references public.wins (id) on delete cascade,
  tag_id uuid not null references public.tags (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (win_id, tag_id)
);

create table public.win_assets (
  id uuid primary key default gen_random_uuid(),
  win_id uuid not null references public.wins (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  storage_path text not null,
  position integer not null default 0,
  mime_type text not null,
  width integer,
  height integer,
  byte_size bigint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

