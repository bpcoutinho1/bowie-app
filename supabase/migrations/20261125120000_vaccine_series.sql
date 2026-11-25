-- The vaccine a tutor joined a dose to, when its name alone does not say it
-- ("Nobivac Canine" as a dose of "DHPPi+L"). Empty follows the name
-- (docs/produto/saude.md#mesma-vacina-com-outro-nome). Safe to run more
-- than once.

alter table public.pet_vaccines
  add column if not exists series text;

alter table public.pet_vaccines
  drop constraint if exists pet_vaccines_series_check,
  add constraint pet_vaccines_series_check
    check (series is null or char_length(series) between 1 and 80);
