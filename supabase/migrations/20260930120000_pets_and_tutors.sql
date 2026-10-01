-- Pets and the people invited to care for them.
-- A pet has one owner. Other people are tutors until they accept.

create table public.pets (
  id uuid primary key,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  updated_at timestamptz not null,
  deleted_at timestamptz
);

create table public.pet_tutors (
  id uuid primary key,
  pet_id uuid not null references public.pets (id) on delete cascade,
  user_id uuid references auth.users (id),
  email text not null check (position('@' in email) > 1),
  role text not null check (role in ('owner', 'tutor')),
  status text not null check (status in ('pending', 'accepted')),
  updated_at timestamptz not null,
  deleted_at timestamptz
);

create index pets_updated_at_idx on public.pets (updated_at);
create index pet_tutors_pet_id_idx on public.pet_tutors (pet_id);
create index pet_tutors_user_id_idx on public.pet_tutors (user_id);
create index pet_tutors_updated_at_idx on public.pet_tutors (updated_at);

create unique index pet_tutors_one_owner_idx
  on public.pet_tutors (pet_id)
  where role = 'owner' and deleted_at is null;

create unique index pet_tutors_active_email_idx
  on public.pet_tutors (pet_id, lower(email))
  where deleted_at is null;

create or replace function public.is_accepted_member(target_pet uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.pet_tutors
    where pet_id = target_pet
      and user_id = auth.uid()
      and status = 'accepted'
      and deleted_at is null
  );
$$;

create or replace function public.is_pet_owner(target_pet uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.pet_tutors
    where pet_id = target_pet
      and user_id = auth.uid()
      and role = 'owner'
      and status = 'accepted'
      and deleted_at is null
  );
$$;

create or replace function public.pet_has_owner(target_pet uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.pet_tutors
    where pet_id = target_pet
      and role = 'owner'
      and deleted_at is null
  );
$$;

create or replace function public.protect_pet_tutor_identity()
returns trigger
language plpgsql
as $$
begin
  if new.id is distinct from old.id
     or new.pet_id is distinct from old.pet_id
     or new.email is distinct from old.email
     or new.role is distinct from old.role then
    raise exception 'pet tutor identity cannot change';
  end if;
  return new;
end;
$$;

create trigger pet_tutors_protect_identity
before update on public.pet_tutors
for each row execute function public.protect_pet_tutor_identity();

alter table public.pets enable row level security;
alter table public.pet_tutors enable row level security;

create policy pets_select on public.pets
for select to authenticated
using (
  public.is_accepted_member(id)
  or exists (
    select 1
    from public.pet_tutors as tutor
    where tutor.pet_id = pets.id
      and tutor.deleted_at is null
      and tutor.status = 'pending'
      and lower(tutor.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
);

create policy pets_insert on public.pets
for insert to authenticated
with check (auth.uid() is not null);

create policy pets_update on public.pets
for update to authenticated
using (public.is_accepted_member(id))
with check (public.is_accepted_member(id));

create policy pet_tutors_select on public.pet_tutors
for select to authenticated
using (
  user_id = auth.uid()
  or lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  or public.is_accepted_member(pet_id)
);

create policy pet_tutors_insert on public.pet_tutors
for insert to authenticated
with check (
  (
    role = 'owner'
    and status = 'accepted'
    and user_id = auth.uid()
    and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    and not public.pet_has_owner(pet_id)
  )
  or (
    public.is_pet_owner(pet_id)
    and role = 'tutor'
    and status = 'pending'
    and user_id is null
  )
);

create policy pet_tutors_update on public.pet_tutors
for update to authenticated
using (
  public.is_pet_owner(pet_id)
  or (
    status = 'pending'
    and role = 'tutor'
    and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
)
with check (
  public.is_pet_owner(pet_id)
  or (
    status = 'accepted'
    and role = 'tutor'
    and user_id = auth.uid()
    and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    and deleted_at is null
  )
);

revoke all on table public.pets from anon;
revoke all on table public.pet_tutors from anon;
grant select, insert, update on table public.pets to authenticated;
grant select, insert, update on table public.pet_tutors to authenticated;

revoke all on function public.is_accepted_member(uuid) from public;
revoke all on function public.is_pet_owner(uuid) from public;
revoke all on function public.pet_has_owner(uuid) from public;
revoke all on function public.protect_pet_tutor_identity() from public;
grant execute on function public.is_accepted_member(uuid) to authenticated;
grant execute on function public.is_pet_owner(uuid) to authenticated;
grant execute on function public.pet_has_owner(uuid) to authenticated;

comment on table public.pets is 'A pet people share care of.';
comment on table public.pet_tutors is 'The owner and invited tutors for a pet.';
