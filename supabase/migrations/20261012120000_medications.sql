-- Medications and the doses marked as given (docs/produto/saude.md#medicamentos).
-- Safe to run more than once.

create table if not exists public.pet_medications (
  id uuid primary key,
  pet_id uuid not null references public.pets (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80 and name = btrim(name)),
  strength text check (strength is null or char_length(strength) <= 40),
  amount numeric(6, 2) not null check (amount > 0 and amount <= 100),
  unit text not null check (unit in (
    'tablet', 'chew', 'capsule', 'drop', 'ml', 'sachet', 'pipette',
    'application', 'collar', 'unit'
  )),
  frequency text not null check (frequency in (
    'daily', 'weekly', 'monthly', 'every_days', 'every_months'
  )),
  interval_count integer not null default 1 check (interval_count between 1 and 365),
  -- [{"period": "morning", "time": "07:00"}], only for daily medications.
  times text not null default '[]',
  start_on date not null,
  end_on date check (end_on is null or end_on >= start_on),
  notes text check (notes is null or char_length(notes) <= 500),
  updated_by uuid references auth.users (id),
  updated_at timestamptz not null,
  deleted_at timestamptz
);

create index if not exists pet_medications_pet_idx on public.pet_medications (pet_id);

create table if not exists public.pet_medication_doses (
  id uuid primary key,
  medication_id uuid not null references public.pet_medications (id) on delete cascade,
  pet_id uuid not null references public.pets (id) on delete cascade,
  due_on date not null,
  period text check (period is null or period in ('morning', 'afternoon', 'night')),
  given_by uuid not null references auth.users (id),
  given_by_email text not null,
  given_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz
);

create index if not exists pet_medication_doses_pet_idx
  on public.pet_medication_doses (pet_id, due_on);

create or replace function public.protect_pet_medication_identity()
returns trigger
language plpgsql
as $$
begin
  if new.id is distinct from old.id or new.pet_id is distinct from old.pet_id then
    raise exception 'medication identity cannot change';
  end if;
  return new;
end;
$$;

drop trigger if exists pet_medications_protect_identity on public.pet_medications;
create trigger pet_medications_protect_identity
before update on public.pet_medications
for each row execute function public.protect_pet_medication_identity();

drop trigger if exists pet_medication_doses_protect_identity on public.pet_medication_doses;
create trigger pet_medication_doses_protect_identity
before update on public.pet_medication_doses
for each row execute function public.protect_pet_medication_identity();

alter table public.pet_medications enable row level security;
alter table public.pet_medication_doses enable row level security;

drop policy if exists pet_medications_select on public.pet_medications;
create policy pet_medications_select on public.pet_medications
for select to authenticated
using (public.is_accepted_member(pet_id));

drop policy if exists pet_medications_insert on public.pet_medications;
create policy pet_medications_insert on public.pet_medications
for insert to authenticated
with check (public.is_accepted_member(pet_id) and updated_by = auth.uid());

drop policy if exists pet_medications_update on public.pet_medications;
create policy pet_medications_update on public.pet_medications
for update to authenticated
using (public.is_accepted_member(pet_id))
with check (public.is_accepted_member(pet_id) and updated_by = auth.uid());

-- Any tutor marks or undoes a dose. The row keeps who gave it; a tutor can
-- only record themselves as the giver.
drop policy if exists pet_medication_doses_select on public.pet_medication_doses;
create policy pet_medication_doses_select on public.pet_medication_doses
for select to authenticated
using (public.is_accepted_member(pet_id));

drop policy if exists pet_medication_doses_insert on public.pet_medication_doses;
create policy pet_medication_doses_insert on public.pet_medication_doses
for insert to authenticated
with check (public.is_accepted_member(pet_id) and given_by = auth.uid());

drop policy if exists pet_medication_doses_update on public.pet_medication_doses;
create policy pet_medication_doses_update on public.pet_medication_doses
for update to authenticated
using (public.is_accepted_member(pet_id))
with check (public.is_accepted_member(pet_id));

revoke all on table public.pet_medications from anon;
revoke all on table public.pet_medication_doses from anon;
grant select, insert, update on table public.pet_medications to authenticated;
grant select, insert, update on table public.pet_medication_doses to authenticated;
revoke all on function public.protect_pet_medication_identity() from public;
