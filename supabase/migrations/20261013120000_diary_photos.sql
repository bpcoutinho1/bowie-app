-- Photos in diary entries (docs/produto/diario.md). The files go to the
-- private bucket "pet-photos" (20261008120000), under the pet's folder, so only
-- the pet's accepted tutors can see them. Safe to run more than once.

-- JSON list of paths: ["<pet id>/<photo id>.jpg", ...], up to 4.
alter table public.pet_events
  add column if not exists photo_paths text not null default '[]';

alter table public.pet_events drop constraint if exists pet_events_photo_paths_check;
alter table public.pet_events
  add constraint pet_events_photo_paths_check check (char_length(photo_paths) <= 1000);
