-- Account deletion (docs/produto/contas-e-tutores.md#exclusão-da-conta).
-- The delete-account Edge Function calls delete_account with the service
-- key, removes the files of the pets that went with the account and then
-- deletes the person from auth.users. Safe to run more than once.

-- Records the person made stay with the pets that live on, without the
-- author; the links the person shared stop working.
alter table public.pet_tutors
  drop constraint if exists pet_tutors_user_id_fkey,
  add constraint pet_tutors_user_id_fkey
    foreign key (user_id) references auth.users (id) on delete set null;

alter table public.shopping_items
  drop constraint if exists shopping_items_updated_by_fkey,
  add constraint shopping_items_updated_by_fkey
    foreign key (updated_by) references auth.users (id) on delete set null;

alter table public.house_contacts
  drop constraint if exists house_contacts_updated_by_fkey,
  add constraint house_contacts_updated_by_fkey
    foreign key (updated_by) references auth.users (id) on delete set null;

alter table public.pet_events
  drop constraint if exists pet_events_updated_by_fkey,
  add constraint pet_events_updated_by_fkey
    foreign key (updated_by) references auth.users (id) on delete set null;

alter table public.pet_medications
  drop constraint if exists pet_medications_updated_by_fkey,
  add constraint pet_medications_updated_by_fkey
    foreign key (updated_by) references auth.users (id) on delete set null;

alter table public.pet_medication_doses
  alter column given_by drop not null,
  drop constraint if exists pet_medication_doses_given_by_fkey,
  add constraint pet_medication_doses_given_by_fkey
    foreign key (given_by) references auth.users (id) on delete set null;

alter table public.pet_health_notes
  drop constraint if exists pet_health_notes_updated_by_fkey,
  add constraint pet_health_notes_updated_by_fkey
    foreign key (updated_by) references auth.users (id) on delete set null;

alter table public.pet_shares
  drop constraint if exists pet_shares_created_by_fkey,
  add constraint pet_shares_created_by_fkey
    foreign key (created_by) references auth.users (id) on delete cascade;

-- The role of a tutor row may change only inside a transfer; the email only
-- when the row is erased with the account.
create or replace function public.protect_pet_tutor_identity()
returns trigger
language plpgsql
as $$
begin
  if new.id is distinct from old.id
     or new.pet_id is distinct from old.pet_id
     or (
       new.email is distinct from old.email
       and not (
         coalesce(current_setting('bowie.erasing', true), '') = 'on'
         and new.deleted_at is not null
       )
     )
     or (
       new.role is distinct from old.role
       and coalesce(current_setting('bowie.transferring', true), '') <> 'on'
     ) then
    raise exception 'pet tutor identity cannot change';
  end if;
  return new;
end;
$$;

-- Erases what belongs to the account, in one transaction:
--   * a pet the person is the main tutor of goes to the tutor chosen in
--     [transfers] ({"<pet id>": "<pet_tutors id>"}) when it has other tutors
--     who accepted, and is deleted, with all its records, when it has none;
--   * the person leaves every other pet, and the email is removed from
--     those rows and from the doses the person gave (the other tutors'
--     phones sync both).
-- Returns the ids of the deleted pets, whose files the caller removes.
-- Raises P0001 when a pet with other tutors has no valid choice.
create or replace function public.delete_account(target uuid, transfers jsonb default '{}'::jsonb)
returns uuid[]
language plpgsql
security definer
set search_path = public
as $$
declare
  now_utc timestamptz := now();
  target_email text;
  owned record;
  heir uuid;
  gone uuid[] := '{}';
begin
  select lower(email) into target_email from auth.users where id = target;
  if not found then
    raise exception 'account not found' using errcode = 'P0002';
  end if;

  for owned in
    select pet_id
    from public.pet_tutors
    where user_id = target
      and role = 'owner'
      and deleted_at is null
  loop
    if exists (
      select 1
      from public.pet_tutors
      where pet_id = owned.pet_id
        and role = 'tutor'
        and status = 'accepted'
        and user_id is not null
        and user_id <> target
        and deleted_at is null
    ) then
      heir := null;
      begin
        heir := nullif(transfers ->> owned.pet_id::text, '')::uuid;
      exception when invalid_text_representation then
        heir := null;
      end;
      if heir is null or not exists (
        select 1
        from public.pet_tutors
        where id = heir
          and pet_id = owned.pet_id
          and role = 'tutor'
          and status = 'accepted'
          and user_id is not null
          and user_id <> target
          and deleted_at is null
      ) then
        raise exception 'choose the new main tutor of pet %', owned.pet_id
          using errcode = 'P0001';
      end if;
      perform set_config('bowie.transferring', 'on', true);
      update public.pet_tutors
      set role = 'tutor', updated_at = now_utc
      where pet_id = owned.pet_id
        and role = 'owner'
        and deleted_at is null;
      update public.pet_tutors
      set role = 'owner', updated_at = now_utc
      where id = heir;
      perform set_config('bowie.transferring', 'off', true);
    else
      delete from public.pets where id = owned.pet_id;
      gone := gone || owned.pet_id;
    end if;
  end loop;

  -- Leaves the pets that live on, invites included.
  perform set_config('bowie.erasing', 'on', true);
  update public.pet_tutors
  set deleted_at = coalesce(deleted_at, now_utc),
      updated_at = now_utc,
      user_id = null,
      email = 'conta-excluida+' || id || '@bowieapp.invalid'
  where user_id = target
     or lower(email) = target_email;
  perform set_config('bowie.erasing', 'off', true);

  -- The doses the person gave stay in the history, without the email.
  update public.pet_medication_doses
  set given_by_email = 'conta-excluida@bowieapp.invalid',
      updated_at = now_utc
  where given_by = target
     or lower(given_by_email) = target_email;

  update public.pet_vaccines
  set updated_by = null
  where updated_by = target;

  return gone;
end;
$$;

revoke all on function public.delete_account(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.delete_account(uuid, jsonb) to service_role;
