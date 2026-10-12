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

-- Vaccine proofs ---------------------------------------------------------------
-- Photos of the vial label and the vet's stamp, as a JSON list of paths in the
-- pet-photos bucket, like pet_events.photo_paths.

alter table public.pet_vaccines
  add column if not exists proof_paths text not null default '[]';

alter table public.pet_vaccines drop constraint if exists pet_vaccines_proof_paths_check;
alter table public.pet_vaccines
  add constraint pet_vaccines_proof_paths_check check (char_length(proof_paths) <= 1000);

-- Files in the diary ------------------------------------------------------------
-- PDFs (exam results, prescriptions) as a JSON list of {path, name}, in the
-- same bucket as the photos. The bucket now takes PDFs up to 10 MB.

alter table public.pet_events
  add column if not exists files text not null default '[]';

alter table public.pet_events drop constraint if exists pet_events_files_check;
alter table public.pet_events
  add constraint pet_events_files_check check (char_length(files) <= 3000);

update storage.buckets
set file_size_limit = 10485760,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
where id = 'pet-photos';

-- Shared pet sheet ---------------------------------------------------------------
-- A link a tutor sends to a hotel, a daycare or a vet. Whoever has the token
-- sees the sheet (through the pet-share Edge Function) until it expires, 60
-- days after it was made, or until a tutor cancels it. The data is always the
-- current one: the link points to the pet, not to a copy.

create table if not exists public.pet_shares (
  id uuid primary key,
  pet_id uuid not null references public.pets (id) on delete cascade,
  token text not null unique check (token ~ '^[A-Za-z0-9_-]{32,64}$'),
  -- care: hotel or daycare. vet: everything, the diary included.
  preset text not null check (preset in ('care', 'vet')),
  label text check (label is null or (char_length(label) between 1 and 60 and label = btrim(label))),
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  -- Set by the server, so a wrong phone clock does not change it.
  expires_at timestamptz not null default (now() + interval '60 days'),
  revoked_at timestamptz,
  last_viewed_at timestamptz,
  constraint pet_shares_expiry_check check (
    expires_at > created_at and expires_at <= created_at + interval '61 days'
  )
);

create index if not exists pet_shares_pet_idx on public.pet_shares (pet_id);

-- Only the cancel (and the view time, set by the server) can change.
create or replace function public.protect_pet_share()
returns trigger
language plpgsql
as $$
begin
  if new.id is distinct from old.id
    or new.pet_id is distinct from old.pet_id
    or new.token is distinct from old.token
    or new.preset is distinct from old.preset
    or new.label is distinct from old.label
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at
    or new.expires_at is distinct from old.expires_at then
    raise exception 'a shared link can only be canceled';
  end if;
  if old.revoked_at is not null and new.revoked_at is distinct from old.revoked_at then
    raise exception 'a canceled link stays canceled';
  end if;
  return new;
end;
$$;

drop trigger if exists pet_shares_protect on public.pet_shares;
create trigger pet_shares_protect
before update on public.pet_shares
for each row execute function public.protect_pet_share();

alter table public.pet_shares enable row level security;

drop policy if exists pet_shares_select on public.pet_shares;
create policy pet_shares_select on public.pet_shares
for select to authenticated
using (public.is_accepted_member(pet_id));

drop policy if exists pet_shares_insert on public.pet_shares;
create policy pet_shares_insert on public.pet_shares
for insert to authenticated
with check (
  public.is_accepted_member(pet_id)
  and created_by = auth.uid()
  and revoked_at is null
  and last_viewed_at is null
  and expires_at <= now() + interval '61 days'
);

drop policy if exists pet_shares_update on public.pet_shares;
create policy pet_shares_update on public.pet_shares
for update to authenticated
using (public.is_accepted_member(pet_id))
with check (public.is_accepted_member(pet_id));

revoke all on table public.pet_shares from anon;
grant select, insert, update on table public.pet_shares to authenticated;
revoke all on function public.protect_pet_share() from public;
