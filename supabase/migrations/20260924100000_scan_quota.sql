-- Daily scan cap: Free 2, Pro 8 (PLAN.md). Enforced here, before Gemini is ever
-- called, so the cap is a cost control and not just a UI hint.

create function public.scan_limit(p_user uuid) returns integer
language sql stable security definer set search_path = '' as $$
  select case
    when p.subscription_tier = 'pro'
     and (p.subscription_expires_at is null or p.subscription_expires_at > now())
    then 8 else 2 end
  from public.profiles p
  where p.id = p_user;
$$;

-- Takes one scan from today's allowance. Returns the scans used after this one,
-- or null when the day's allowance is already spent. One statement, so two scans
-- racing each other can't both squeeze past the limit.
create function public.consume_scan(p_user uuid, p_date date) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_limit integer := public.scan_limit(p_user);
  v_count integer;
begin
  if v_limit is null then
    return null; -- no profile
  end if;

  insert into public.scan_usage as u (user_id, date, scan_count)
  values (p_user, p_date, 1)
  on conflict (user_id, date) do update
    set scan_count = u.scan_count + 1
    where u.scan_count < v_limit
  returning u.scan_count into v_count;

  return v_count; -- null when the where clause blocked the update
end;
$$;

-- Gives a scan back when it didn't produce a meal (not food, or the model failed).
create function public.refund_scan(p_user uuid, p_date date) returns void
language sql security definer set search_path = '' as $$
  update public.scan_usage
     set scan_count = greatest(scan_count - 1, 0)
   where user_id = p_user and date = p_date;
$$;

-- Only the analyze-meal Edge Function (service role) spends scans.
revoke execute on function public.scan_limit(uuid) from public, anon, authenticated;
revoke execute on function public.consume_scan(uuid, date) from public, anon, authenticated;
revoke execute on function public.refund_scan(uuid, date) from public, anon, authenticated;
grant execute on function public.scan_limit(uuid) to service_role;
grant execute on function public.consume_scan(uuid, date) to service_role;
grant execute on function public.refund_scan(uuid, date) to service_role;
