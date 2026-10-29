-- The size of a dog chosen by a tutor. Empty means it follows the weight
-- (docs/produto/pets.md#porte). Safe to run more than once.

alter table public.pets
  add column if not exists size text;

alter table public.pets
  drop constraint if exists pets_size_check,
  add constraint pets_size_check
    check (size is null or size in ('mini', 'small', 'medium', 'large', 'giant'));
