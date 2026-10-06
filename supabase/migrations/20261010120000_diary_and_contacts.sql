-- The pet diary (docs/produto/diario.md) and the house contacts
-- (docs/produto/contatos.md). Needs 20261009120000_shopping_items.sql
-- (is_house_member). Safe to run more than once.

-- Contacts ------------------------------------------------------------------

create table if not exists public.house_contacts (
  id uuid primary key,
  house_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80 and name = btrim(name)),
  category text not null check (category in (
    'vet', 'nutritionist', 'physio', 'trainer', 'daycare', 'hotel',
    'groomer', 'walker', 'lab', 'pet_shop', 'other'
  )),
  phone text check (phone is null or phone ~ '^[0-9]{10,11}$'),
  email text check (email is null or (char_length(email) <= 254 and email like '%@%')),
  address text check (address is null or char_length(address) <= 200),
  notes text check (notes is null or char_length(notes) <= 500),
  updated_by uuid references auth.users (id),
  updated_at timestamptz not null,
  deleted_at timestamptz
);

create index if not exists house_contacts_house_idx on public.house_contacts (house_id);

create or replace function public.protect_house_contact_identity()
returns trigger
language plpgsql
as $$
begin
  if new.id is distinct from old.id or new.house_id is distinct from old.house_id then
    raise exception 'contact identity cannot change';
  end if;
  return new;
end;
$$;

drop trigger if exists house_contacts_protect_identity on public.house_contacts;
create trigger house_contacts_protect_identity
before update on public.house_contacts
for each row execute function public.protect_house_contact_identity();

alter table public.house_contacts enable row level security;

drop policy if exists house_contacts_select on public.house_contacts;
create policy house_contacts_select on public.house_contacts
for select to authenticated
using (public.is_house_member(house_id));

drop policy if exists house_contacts_insert on public.house_contacts;
create policy house_contacts_insert on public.house_contacts
for insert to authenticated
with check (public.is_house_member(house_id) and updated_by = auth.uid());

drop policy if exists house_contacts_update on public.house_contacts;
create policy house_contacts_update on public.house_contacts
for update to authenticated
using (public.is_house_member(house_id))
with check (public.is_house_member(house_id) and updated_by = auth.uid());

revoke all on table public.house_contacts from anon;
grant select, insert, update on table public.house_contacts to authenticated;
revoke all on function public.protect_house_contact_identity() from public;

-- Diary ----------------------------------------------------------------------

create table if not exists public.pet_events (
  id uuid primary key,
  pet_id uuid not null references public.pets (id) on delete cascade,
  kind text not null check (kind in ('symptom', 'vet_visit', 'exam', 'other')),
  title text not null check (char_length(btrim(title)) between 1 and 80 and title = btrim(title)),
  occurs_on date not null,
  occurs_time time,
  notes text check (notes is null or char_length(notes) <= 1000),
  contact_id uuid references public.house_contacts (id) on delete set null,
  updated_by uuid references auth.users (id),
  updated_at timestamptz not null,
  deleted_at timestamptz
);

create index if not exists pet_events_pet_idx on public.pet_events (pet_id);

create or replace function public.protect_pet_event_identity()
returns trigger
language plpgsql
as $$
begin
  if new.id is distinct from old.id or new.pet_id is distinct from old.pet_id then
    raise exception 'diary entry identity cannot change';
  end if;
  return new;
end;
$$;

drop trigger if exists pet_events_protect_identity on public.pet_events;
create trigger pet_events_protect_identity
before update on public.pet_events
for each row execute function public.protect_pet_event_identity();

alter table public.pet_events enable row level security;

drop policy if exists pet_events_select on public.pet_events;
create policy pet_events_select on public.pet_events
for select to authenticated
using (public.is_accepted_member(pet_id));

drop policy if exists pet_events_insert on public.pet_events;
create policy pet_events_insert on public.pet_events
for insert to authenticated
with check (public.is_accepted_member(pet_id) and updated_by = auth.uid());

drop policy if exists pet_events_update on public.pet_events;
create policy pet_events_update on public.pet_events
for update to authenticated
using (public.is_accepted_member(pet_id))
with check (public.is_accepted_member(pet_id) and updated_by = auth.uid());

revoke all on table public.pet_events from anon;
grant select, insert, update on table public.pet_events to authenticated;
revoke all on function public.protect_pet_event_identity() from public;
