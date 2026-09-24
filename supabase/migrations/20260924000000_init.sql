-- NutriStep AI — initial schema.
--
-- Storage is metric + UTC; conversion happens in the app. RLS is on for every
-- table: the app's publishable key can only ever touch the signed-in user's rows.
-- AI results are written by Edge Functions with the service role, never the client.

-- ── profiles ──────────────────────────────────────────────────────────────────
create table public.profiles (
  id                      uuid primary key references auth.users (id) on delete cascade,
  email                   text,
  display_name            text,
  language                text not null default 'en' check (language in ('en', 'so', 'ar')),
  unit_preference         text not null default 'metric' check (unit_preference in ('metric', 'imperial')),
  timezone                text,                      -- IANA, from the device

  -- onboarding answers
  gender                  text check (gender in ('male', 'female')),
  date_of_birth           date,
  height_cm               numeric(5, 1),
  weight_kg               numeric(5, 1),
  goal                    text check (goal in ('lose', 'maintain', 'gain')),
  target_weight_kg        numeric(5, 1),
  activity_level          text check (activity_level in ('sedentary', 'light', 'moderate', 'very', 'extra')),
  pace_kg_per_week        numeric(3, 1),
  diet_preference         text check (diet_preference in ('classic', 'keto', 'vegan', 'vegetarian')),

  -- daily targets
  daily_calories          integer,
  protein_g               integer,
  carbs_g                 integer,
  fat_g                   integer,
  plan_rationale          text,
  plan_source             text check (plan_source in ('ai', 'formula')),
  plan_generated_at       timestamptz,
  onboarding_completed_at timestamptz,

  -- billing: written only by the verify-purchase Edge Function (see the grant below)
  subscription_tier       text not null default 'free' check (subscription_tier in ('free', 'pro')),
  subscription_expires_at timestamptz,

  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

-- ── meals ─────────────────────────────────────────────────────────────────────
create table public.meals (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  image_path    text not null,                        -- path inside the meal-photos bucket
  status        text not null default 'analyzing' check (status in ('analyzing', 'completed', 'failed')),
  name          text,
  portion_grams numeric(6, 1),
  calories      integer,
  protein_g     integer,
  carbs_g       integer,
  fat_g         integer,
  error_reason  text,                                 -- 'not_food' | 'analysis_failed' | …
  source        text check (source in ('ai', 'ai+db', 'user_corrected')),
  logged_at     timestamptz not null default now(),   -- UTC instant
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index meals_user_logged_at_idx on public.meals (user_id, logged_at desc);

-- ── scan_usage: the Free (2/day) vs Pro (8/day) cap, enforced server-side ──────
create table public.scan_usage (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  date       date not null,                           -- the user's local date
  scan_count integer not null default 0,
  primary key (user_id, date)
);

-- ── activity_logs: daily step rollups from Health Connect / HealthKit ─────────
create table public.activity_logs (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles (id) on delete cascade,
  date            date not null,
  steps           integer not null default 0,
  distance_m      numeric(9, 1),
  calories_burned integer,
  synced_at       timestamptz not null default now(),
  unique (user_id, date)
);

-- ── updated_at ────────────────────────────────────────────────────────────────
create function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();
create trigger meals_touch before update on public.meals
  for each row execute function public.touch_updated_at();

-- ── a profile row for every new account ───────────────────────────────────────
-- Created in the same transaction as the auth user, so the app never has to
-- race a webhook for it (cal-ai needed an upsert on both sides for exactly that).
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, email) values (new.id, new.email);
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── row level security ────────────────────────────────────────────────────────
alter table public.profiles      enable row level security;
alter table public.meals         enable row level security;
alter table public.scan_usage    enable row level security;
alter table public.activity_logs enable row level security;

create policy "own profile: read"   on public.profiles for select using ((select auth.uid()) = id);
create policy "own profile: update" on public.profiles for update using ((select auth.uid()) = id);

-- The client may edit its answers and targets, never its own subscription.
revoke update on public.profiles from authenticated;
grant update (
  display_name, language, unit_preference, timezone,
  gender, date_of_birth, height_cm, weight_kg, goal, target_weight_kg,
  activity_level, pace_kg_per_week, diet_preference,
  daily_calories, protein_g, carbs_g, fat_g, plan_rationale, plan_source,
  plan_generated_at, onboarding_completed_at
) on public.profiles to authenticated;

create policy "own meals: read"   on public.meals for select using ((select auth.uid()) = user_id);
create policy "own meals: update" on public.meals for update using ((select auth.uid()) = user_id);
create policy "own meals: delete" on public.meals for delete using ((select auth.uid()) = user_id);
-- no insert policy: meals are created by the analyze-meal Edge Function, after the scan quota check

create policy "own scan usage: read" on public.scan_usage for select using ((select auth.uid()) = user_id);

create policy "own activity: read"   on public.activity_logs for select using ((select auth.uid()) = user_id);
create policy "own activity: insert" on public.activity_logs for insert with check ((select auth.uid()) = user_id);
create policy "own activity: update" on public.activity_logs for update using ((select auth.uid()) = user_id);

-- ── meal photos ───────────────────────────────────────────────────────────────
-- Private bucket; every object lives under "<user id>/…", and that prefix is the
-- whole access rule. 1 MB cap: the app downsizes to ~100 KB before upload.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('meal-photos', 'meal-photos', false, 1048576, array['image/jpeg', 'image/webp']);

create policy "own photos: upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'meal-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "own photos: read" on storage.objects for select to authenticated
  using (bucket_id = 'meal-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "own photos: delete" on storage.objects for delete to authenticated
  using (bucket_id = 'meal-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
