-- Plans: free and Premium, with the 30-day trial and the lifetime counters of
-- the free plan (docs/produto/planos.md). Nothing is charged yet: the plan
-- is set by hand in the Supabase dashboard (docs/guias/planos.md).
-- Safe to run more than once.

create table if not exists public.account_plans (
  user_id uuid primary key references auth.users (id) on delete cascade,
  -- Copied from the account so the table is easy to read in the dashboard.
  email text,
  plan text not null default 'free' check (plan in ('free', 'premium')),
  -- Premium until this moment; null means no end.
  premium_until timestamptz,
  -- Every new account has Premium for 30 days, without a card.
  trial_ends_at timestamptz not null default (now() + interval '30 days'),
  -- Free plan limits count for the life of the account: deleting gives
  -- nothing back.
  ai_photos_used integer not null default 0 check (ai_photos_used >= 0),
  diary_files_used integer not null default 0 check (diary_files_used >= 0),
  updated_at timestamptz not null default now()
);

alter table public.account_plans enable row level security;

-- Each person reads only their own plan. Changes come from the dashboard
-- (or, later, the payment service) and from consume_quota below.
drop policy if exists account_plans_select on public.account_plans;
create policy account_plans_select on public.account_plans
for select to authenticated
using (user_id = auth.uid());

revoke all on table public.account_plans from anon;
revoke insert, update, delete on table public.account_plans from authenticated;
grant select on table public.account_plans to authenticated;

-- New accounts get their row, and with it the trial.
create or replace function public.create_account_plan()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.account_plans (user_id, email)
  values (new.id, new.email)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_plan on auth.users;
create trigger on_auth_user_created_plan
after insert on auth.users
for each row execute function public.create_account_plan();

revoke all on function public.create_account_plan() from public;

-- Accounts made before this: the trial counts from when they were made, so
-- older accounts start on the free plan.
insert into public.account_plans (user_id, email, trial_ends_at)
select id, email, created_at + interval '30 days'
from auth.users
on conflict (user_id) do nothing;

-- The app counts what the free plan limits: photos read by the AI and
-- photos or PDFs sent to the diary.
create or replace function public.consume_quota(kind text, amount integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if amount is null or amount < 1 or amount > 20 then
    raise exception 'invalid amount' using errcode = '22023';
  end if;
  if kind = 'ai_photos' then
    update public.account_plans
    set ai_photos_used = ai_photos_used + amount, updated_at = now()
    where user_id = auth.uid();
  elsif kind = 'diary_files' then
    update public.account_plans
    set diary_files_used = diary_files_used + amount, updated_at = now()
    where user_id = auth.uid();
  else
    raise exception 'unknown quota' using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.consume_quota(text, integer) from public, anon;
grant execute on function public.consume_quota(text, integer) to authenticated;
