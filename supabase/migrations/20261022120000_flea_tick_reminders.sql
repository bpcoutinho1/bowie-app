-- Flea and tick protection (collar, tablet, pipette) as a third kind of dose,
-- and the reminder each dose asks for: 7, 14 or 30 days before it is due
-- (docs/produto/saude.md). Safe to run more than once.

alter table public.pet_vaccines
  drop constraint if exists pet_vaccines_kind_check,
  add constraint pet_vaccines_kind_check
    check (kind in ('vaccine', 'dewormer', 'flea_tick'));

alter table public.pet_vaccines
  add column if not exists remind_days integer not null default 7;

alter table public.pet_vaccines
  drop constraint if exists pet_vaccines_remind_days_check,
  add constraint pet_vaccines_remind_days_check
    check (remind_days in (7, 14, 30));
