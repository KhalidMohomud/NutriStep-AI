-- Preferences the user sets in the app, and the AI Coach's daily allowance.

-- ── preferences on the profile ────────────────────────────────────────────────
alter table public.profiles
  add column step_goal     integer not null default 10000 check (step_goal between 1000 and 50000),
  add column reminder_hour integer not null default 20 check (reminder_hour between 0 and 23);

-- the column grant from the init migration is an allow-list; extend it
grant update (step_goal, reminder_hour) on public.profiles to authenticated;

-- ── coach allowance: Free 3 questions a day, Pro 50 ───────────────────────────
create table public.coach_usage (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  date       date not null,
  used       integer not null default 0,
  primary key (user_id, date)
);

alter table public.coach_usage enable row level security;
create policy "own coach usage: read" on public.coach_usage
  for select using ((select auth.uid()) = user_id);

create function public.coach_limit(p_user uuid) returns integer
language sql stable security definer set search_path = '' as $$
  select case
    when p.subscription_tier = 'pro'
     and (p.subscription_expires_at is null or p.subscription_expires_at > now())
    then 50 else 3 end
  from public.profiles p
  where p.id = p_user;
$$;

-- Same shape as consume_scan: one statement, so racing requests can't both pass.
create function public.consume_coach(p_user uuid, p_date date) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_limit integer := public.coach_limit(p_user);
  v_used integer;
begin
  if v_limit is null then
    return null;
  end if;

  insert into public.coach_usage as u (user_id, date, used)
  values (p_user, p_date, 1)
  on conflict (user_id, date) do update
    set used = u.used + 1
    where u.used < v_limit
  returning u.used into v_used;

  return v_used;
end;
$$;

create function public.refund_coach(p_user uuid, p_date date) returns void
language sql security definer set search_path = '' as $$
  update public.coach_usage
     set used = greatest(used - 1, 0)
   where user_id = p_user and date = p_date;
$$;

revoke execute on function public.coach_limit(uuid) from public, anon, authenticated;
revoke execute on function public.consume_coach(uuid, date) from public, anon, authenticated;
revoke execute on function public.refund_coach(uuid, date) from public, anon, authenticated;
grant execute on function public.coach_limit(uuid) to service_role;
grant execute on function public.consume_coach(uuid, date) to service_role;
grant execute on function public.refund_coach(uuid, date) to service_role;

-- ── feedback: "Send feedback" lands here; read it in the dashboard ────────────
create table public.feedback (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references public.profiles (id) on delete set null,
  message    text not null check (char_length(message) between 1 and 4000),
  app_info   text,                                  -- platform + app version
  created_at timestamptz not null default now()
);

alter table public.feedback enable row level security;
-- write-only for users: they send it, only you (the dashboard) read it
create policy "send own feedback" on public.feedback
  for insert to authenticated with check ((select auth.uid()) = user_id);
