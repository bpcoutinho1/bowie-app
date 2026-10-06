-- Vaccine and dewormer doses. Every accepted tutor of the pet can read,
-- add, edit and delete (soft delete via deleted_at). updated_by records who
-- saved each version.

create table public.pet_vaccines (
  id uuid primary key,
  pet_id uuid not null references public.pets (id) on delete cascade,
  kind text not null check (kind in ('vaccine', 'dewormer')),
  name text not null check (char_length(btrim(name)) between 1 and 80),
  applied_on date not null,
  next_due_on date not null,
  product text check (char_length(product) <= 120),
  lot text check (char_length(lot) <= 120),
  veterinarian text check (char_length(veterinarian) <= 120),
  notes text check (char_length(notes) <= 500),
  updated_by uuid,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  check (next_due_on > applied_on)
);

create index pet_vaccines_pet_id_idx on public.pet_vaccines (pet_id);
create index pet_vaccines_updated_at_idx on public.pet_vaccines (updated_at);

create or replace function public.protect_pet_vaccine_identity()
returns trigger
language plpgsql
as $$
begin
  if new.id is distinct from old.id
     or new.pet_id is distinct from old.pet_id then
    raise exception 'pet vaccine identity cannot change';
  end if;
  return new;
end;
$$;

create trigger pet_vaccines_protect_identity
before update on public.pet_vaccines
for each row execute function public.protect_pet_vaccine_identity();

alter table public.pet_vaccines enable row level security;

create policy pet_vaccines_select on public.pet_vaccines
for select to authenticated
using (public.is_accepted_member(pet_id));

create policy pet_vaccines_insert on public.pet_vaccines
for insert to authenticated
with check (
  public.is_accepted_member(pet_id)
  and updated_by = auth.uid()
);

create policy pet_vaccines_update on public.pet_vaccines
for update to authenticated
using (public.is_accepted_member(pet_id))
with check (
  public.is_accepted_member(pet_id)
  and updated_by = auth.uid()
);

revoke all on table public.pet_vaccines from anon;
grant select, insert, update on table public.pet_vaccines to authenticated;
revoke all on function public.protect_pet_vaccine_identity() from public;

comment on table public.pet_vaccines is 'Vaccine and dewormer doses of a pet.';
