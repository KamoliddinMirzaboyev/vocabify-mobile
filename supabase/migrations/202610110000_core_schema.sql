-- Reproducible core schema for Vocabify.
-- This migration is idempotent so it can also harden an existing project.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  daily_goal integer not null default 20 check (daily_goal between 1 and 500),
  current_streak integer not null default 0 check (current_streak >= 0),
  longest_streak integer not null default 0 check (longest_streak >= 0),
  last_study_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.decks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 120),
  description text,
  color text not null default 'violet',
  icon text not null default '📚',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  deck_id uuid not null references public.decks(id) on delete cascade,
  word text not null check (length(btrim(word)) > 0),
  pronunciation text,
  translation text not null check (length(btrim(translation)) > 0),
  definition text,
  synonyms text,
  antonyms text,
  example_sentence text,
  my_sentence text,
  image_url text,
  ease_factor numeric(4, 2) not null default 2.5 check (ease_factor >= 1.3),
  interval_days integer not null default 0 check (interval_days >= 0),
  repetitions integer not null default 0 check (repetitions >= 0),
  due_date date not null default current_date,
  last_reviewed_at timestamptz,
  total_reviews integer not null default 0 check (total_reviews >= 0),
  correct_reviews integer not null default 0
    check (correct_reviews >= 0 and correct_reviews <= total_reviews),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  card_id uuid not null references public.cards(id) on delete cascade,
  rating integer not null check (rating between 0 and 3),
  reviewed_at timestamptz not null default now()
);

create index if not exists decks_user_created_idx
  on public.decks (user_id, created_at desc);
create index if not exists cards_user_due_idx
  on public.cards (user_id, due_date);
create index if not exists cards_deck_created_idx
  on public.cards (deck_id, created_at desc);
create index if not exists reviews_user_reviewed_idx
  on public.reviews (user_id, reviewed_at desc);
create index if not exists reviews_card_reviewed_idx
  on public.reviews (card_id, reviewed_at desc);

alter table public.profiles enable row level security;
alter table public.decks enable row level security;
alter table public.cards enable row level security;
alter table public.reviews enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'users manage own profile'
  ) then
    create policy "users manage own profile" on public.profiles
      for all to authenticated
      using (auth.uid() = id)
      with check (auth.uid() = id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'decks'
      and policyname = 'users manage own decks'
  ) then
    create policy "users manage own decks" on public.decks
      for all to authenticated
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'cards'
      and policyname = 'users manage own cards'
  ) then
    create policy "users manage own cards" on public.cards
      for all to authenticated
      using (auth.uid() = user_id)
      with check (
        auth.uid() = user_id
        and exists (
          select 1 from public.decks d
          where d.id = deck_id and d.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'reviews'
      and policyname = 'users manage own reviews'
  ) then
    create policy "users manage own reviews" on public.reviews
      for all to authenticated
      using (auth.uid() = user_id)
      with check (
        auth.uid() = user_id
        and exists (
          select 1 from public.cards c
          where c.id = card_id and c.user_id = auth.uid()
        )
      );
  end if;
end;
$$;

revoke all on public.profiles, public.decks, public.cards, public.reviews
  from anon;
grant select, insert, update, delete
  on public.profiles, public.decks, public.cards, public.reviews
  to authenticated;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists decks_set_updated_at on public.decks;
create trigger decks_set_updated_at
before update on public.decks
for each row execute function public.set_updated_at();

drop trigger if exists cards_set_updated_at on public.cards;
create trigger cards_set_updated_at
before update on public.cards
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(btrim(new.raw_user_meta_data->>'display_name'), ''),
             split_part(coalesce(new.email, 'Learner'), '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

