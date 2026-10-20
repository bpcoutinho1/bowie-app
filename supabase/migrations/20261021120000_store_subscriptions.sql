-- Premium bought in the App Store or Google Play, through RevenueCat
-- (docs/funcionamento/planos.md). The revenuecat-webhook Edge Function writes
-- these columns with the service key; the plan set by hand in the dashboard
-- (plan, premium_until) stays separate, so one never erases the other.
-- Safe to run more than once.

alter table public.account_plans
  -- Until when the store subscription is paid; null means none.
  add column if not exists store_premium_until timestamptz,
  -- The product bought, like bowie.premium.monthly.
  add column if not exists store_product text,
  add column if not exists store_updated_at timestamptz;
