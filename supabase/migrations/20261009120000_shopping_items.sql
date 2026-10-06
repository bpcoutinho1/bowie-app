-- Shopping list shared by a house (docs/produto/compras.md).
-- A house is identified by its main tutor's user id: it gathers every pet that
-- person is the main tutor of, and everyone who cares for one of them.
-- Safe to run more than once.

create table if not exists public.shopping_items (
  id uuid primary key,
  house_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80 and name = btrim(name)),
  details text check (details is null or char_length(details) <= 120),
  catalog_key text check (catalog_key is null or char_length(catalog_key) <= 40),
  status text not null check (status in ('to_buy', 'bought')),
  updated_by uuid references auth.users (id),
  updated_at timestamptz not null,
  deleted_at timestamptz
);

create index if not exists shopping_items_house_idx on public.shopping_items (house_id);

-- True when the current user belongs to the house: it is their own, or they are
-- an accepted tutor of a pet whose main tutor owns it.
create or replace function public.is_house_member(target_house uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select target_house = auth.uid()
    or exists (
      select 1
      from public.pet_tutors as me
      join public.pets as pet on pet.id = me.pet_id and pet.deleted_at is null
      join public.pet_tutors as owner
        on owner.pet_id = me.pet_id
       and owner.role = 'owner'
       and owner.status = 'accepted'
       and owner.deleted_at is null
      where me.user_id = auth.uid()
        and me.status = 'accepted'
        and me.deleted_at is null
        and owner.user_id = target_house
    );
$$;

revoke all on function public.is_house_member(uuid) from public;
grant execute on function public.is_house_member(uuid) to authenticated;

create or replace function public.protect_shopping_item_identity()
returns trigger
language plpgsql
as $$
begin
  if new.id is distinct from old.id or new.house_id is distinct from old.house_id then
    raise exception 'shopping item identity cannot change';
  end if;
  return new;
end;
$$;

drop trigger if exists shopping_items_protect_identity on public.shopping_items;
create trigger shopping_items_protect_identity
before update on public.shopping_items
for each row execute function public.protect_shopping_item_identity();

alter table public.shopping_items enable row level security;

drop policy if exists shopping_items_select on public.shopping_items;
create policy shopping_items_select on public.shopping_items
for select to authenticated
using (public.is_house_member(house_id));

drop policy if exists shopping_items_insert on public.shopping_items;
create policy shopping_items_insert on public.shopping_items
for insert to authenticated
with check (public.is_house_member(house_id) and updated_by = auth.uid());

drop policy if exists shopping_items_update on public.shopping_items;
create policy shopping_items_update on public.shopping_items
for update to authenticated
using (public.is_house_member(house_id))
with check (public.is_house_member(house_id) and updated_by = auth.uid());

revoke all on table public.shopping_items from anon;
grant select, insert, update on table public.shopping_items to authenticated;
revoke all on function public.protect_shopping_item_identity() from public;

comment on table public.shopping_items is 'Shopping list of a house; house_id is the main tutor''s user id.';
