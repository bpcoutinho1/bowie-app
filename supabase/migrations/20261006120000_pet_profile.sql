-- Pet profile: species, breed, birth date and weight.
-- Only the main tutor can delete a pet (set deleted_at).

alter table public.pets
  add column species text check (species in ('dog', 'cat')),
  add column breed text check (char_length(breed) <= 80),
  add column birth_date date,
  add column birth_date_estimated boolean not null default false,
  add column weight_kg numeric(4, 1) check (weight_kg > 0 and weight_kg <= 150);

create or replace function public.protect_pet_deletion()
returns trigger
language plpgsql
as $$
begin
  if new.deleted_at is distinct from old.deleted_at
     and not public.is_pet_owner(old.id) then
    raise exception 'only the main tutor can delete a pet';
  end if;
  return new;
end;
$$;

create trigger pets_protect_deletion
before update on public.pets
for each row execute function public.protect_pet_deletion();

revoke all on function public.protect_pet_deletion() from public;
