-- New accounts start on the free plan, with no Premium trial (decision of
-- 22 October 2026, docs/produto/planos.md). Accounts already in a trial keep
-- it until it ends. A trial can still be given by hand (docs/guias/planos.md).
-- Safe to run more than once.

alter table public.account_plans
  alter column trial_ends_at set default now();
