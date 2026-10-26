-- 1. Weighings in the diary: an entry of kind 'weight' keeps the weight in
--    kg, and the pet's page draws the chart from them
--    (docs/produto/diario.md#peso).
-- 2. When each pet was registered: the notice about missing vaccines waits
--    7 days after it (docs/produto/notificacoes.md).
-- Safe to run more than once.

alter table public.pet_events
  add column if not exists weight_kg numeric(4, 1);

alter table public.pet_events
  drop constraint if exists pet_events_kind_check,
  add constraint pet_events_kind_check
    check (kind in ('symptom', 'vet_visit', 'exam', 'weight', 'other'));

-- A weighing has a weight between 0,1 and 150 kg. Other kinds are not held
-- to a null weight: an older app that edits a weighing (it does not know the
-- kind) keeps the column as it was, and its sync must not fail.
alter table public.pet_events
  drop constraint if exists pet_events_weight_check,
  add constraint pet_events_weight_check
    check (
      (weight_kg is null or (weight_kg > 0 and weight_kg <= 150))
      and (kind <> 'weight' or weight_kg is not null)
    );

-- When the pet was registered. Pets made before this get the earliest date
-- the server has for them.
alter table public.pets
  add column if not exists created_at timestamptz;

update public.pets as pet
set created_at = least(
  pet.updated_at,
  coalesce(
    (select min(tutor.updated_at) from public.pet_tutors as tutor where tutor.pet_id = pet.id),
    pet.updated_at
  )
)
where pet.created_at is null;

alter table public.pets
  alter column created_at set default now(),
  alter column created_at set not null;

-- The server keeps the date: set on insert, never changed after.
create or replace function public.keep_pet_created_at()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
  else
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;

drop trigger if exists pets_keep_created_at on public.pets;
create trigger pets_keep_created_at
before insert or update on public.pets
for each row execute function public.keep_pet_created_at();

revoke all on function public.keep_pet_created_at() from public;
