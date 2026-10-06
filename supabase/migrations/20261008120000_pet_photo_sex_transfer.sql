-- Pet sex and profile photo, and transferring a pet to another tutor.
-- Safe to run more than once.

-- Sex ------------------------------------------------------------------------

alter table public.pets add column if not exists sex text;

alter table public.pets drop constraint if exists pets_sex_check;
alter table public.pets
  add constraint pets_sex_check check (sex is null or sex in ('male', 'female'));

-- Photo ----------------------------------------------------------------------

-- Path of the photo in the private bucket "pet-photos": "<pet id>/<photo id>.jpg"
-- (or .png, .webp).
alter table public.pets add column if not exists photo_path text;

alter table public.pets drop constraint if exists pets_photo_path_check;
alter table public.pets
  add constraint pets_photo_path_check check (
    photo_path is null
    or photo_path = id::text || '/' || split_part(photo_path, '/', 2)
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'pet-photos', 'pet-photos', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- The pet a photo belongs to, from its path; null for anything else.
create or replace function public.pet_of_photo(object_name text)
returns uuid
language sql
immutable
as $$
  select case
    when object_name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[^/]+$'
      then split_part(object_name, '/', 1)::uuid
  end;
$$;

grant execute on function public.pet_of_photo(text) to authenticated;

-- Only accepted tutors of the pet see, add, replace or remove its photos.
drop policy if exists pet_photos_select on storage.objects;
create policy pet_photos_select on storage.objects
for select to authenticated
using (
  bucket_id = 'pet-photos'
  and public.is_accepted_member(public.pet_of_photo(name))
);

drop policy if exists pet_photos_insert on storage.objects;
create policy pet_photos_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'pet-photos'
  and public.is_accepted_member(public.pet_of_photo(name))
);

drop policy if exists pet_photos_update on storage.objects;
create policy pet_photos_update on storage.objects
for update to authenticated
using (
  bucket_id = 'pet-photos'
  and public.is_accepted_member(public.pet_of_photo(name))
)
with check (
  bucket_id = 'pet-photos'
  and public.is_accepted_member(public.pet_of_photo(name))
);

drop policy if exists pet_photos_delete on storage.objects;
create policy pet_photos_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'pet-photos'
  and public.is_accepted_member(public.pet_of_photo(name))
);

-- Transfer -------------------------------------------------------------------

-- The role of a tutor row may change only inside transfer_pet.
create or replace function public.protect_pet_tutor_identity()
returns trigger
language plpgsql
as $$
begin
  if new.id is distinct from old.id
     or new.pet_id is distinct from old.pet_id
     or new.email is distinct from old.email
     or (
       new.role is distinct from old.role
       and coalesce(current_setting('bowie.transferring', true), '') <> 'on'
     ) then
    raise exception 'pet tutor identity cannot change';
  end if;
  return new;
end;
$$;

-- The main tutor hands the pet to a tutor who already accepted the invite.
-- The former main tutor stays as a regular tutor.
create or replace function public.transfer_pet(target_pet uuid, new_owner uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  now_utc timestamptz := now();
begin
  if not public.is_pet_owner(target_pet) then
    raise exception 'only the main tutor can transfer the pet'
      using errcode = '42501';
  end if;
  if not exists (
    select 1
    from public.pet_tutors
    where id = new_owner
      and pet_id = target_pet
      and role = 'tutor'
      and status = 'accepted'
      and user_id is not null
      and deleted_at is null
  ) then
    raise exception 'the new main tutor must have accepted the invite'
      using errcode = 'P0002';
  end if;

  perform set_config('bowie.transferring', 'on', true);
  -- Demote first: only one active owner per pet is allowed.
  update public.pet_tutors
  set role = 'tutor', updated_at = now_utc
  where pet_id = target_pet
    and role = 'owner'
    and deleted_at is null;
  update public.pet_tutors
  set role = 'owner', updated_at = now_utc
  where id = new_owner;
  perform set_config('bowie.transferring', 'off', true);
end;
$$;

revoke all on function public.transfer_pet(uuid, uuid) from public;
grant execute on function public.transfer_pet(uuid, uuid) to authenticated;
