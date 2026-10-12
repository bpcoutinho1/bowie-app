-- Allergies, diet and special care; vaccine proofs; files in the diary; and
-- the pet sheet shared with hotels, daycares and vets.
-- Safe to run more than once.

-- Allergies, diet and special care --------------------------------------------

create table if not exists public.pet_health_notes (
  id uuid primary key,
  pet_id uuid not null references public.pets (id) on delete cascade,
  kind text not null check (kind in ('special_care', 'allergy', 'diet')),
  title text not null check (char_length(btrim(title)) between 1 and 80 and title = btrim(title)),
  details text check (details is null or char_length(details) <= 500),
  updated_by uuid references auth.users (id),
  updated_at timestamptz not null,
  deleted_at timestamptz
);

create index if not exists pet_health_notes_pet_idx on public.pet_health_notes (pet_id);

create or replace function public.protect_pet_health_note_identity()
returns trigger
language plpgsql
as $$
begin
  if new.id is distinct from old.id or new.pet_id is distinct from old.pet_id then
    raise exception 'health note identity cannot change';
  end if;
  return new;
end;
$$;

drop trigger if exists pet_health_notes_protect_identity on public.pet_health_notes;
create trigger pet_health_notes_protect_identity
before update on public.pet_health_notes
for each row execute function public.protect_pet_health_note_identity();

alter table public.pet_health_notes enable row level security;

drop policy if exists pet_health_notes_select on public.pet_health_notes;
create policy pet_health_notes_select on public.pet_health_notes
for select to authenticated
using (public.is_accepted_member(pet_id));

drop policy if exists pet_health_notes_insert on public.pet_health_notes;
create policy pet_health_notes_insert on public.pet_health_notes
for insert to authenticated
with check (public.is_accepted_member(pet_id) and updated_by = auth.uid());

drop policy if exists pet_health_notes_update on public.pet_health_notes;
create policy pet_health_notes_update on public.pet_health_notes
for update to authenticated
using (public.is_accepted_member(pet_id))
with check (public.is_accepted_member(pet_id) and updated_by = auth.uid());

revoke all on table public.pet_health_notes from anon;
grant select, insert, update on table public.pet_health_notes to authenticated;
revoke all on function public.protect_pet_health_note_identity() from public;
