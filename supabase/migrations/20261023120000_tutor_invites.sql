-- Invitation emails (docs/produto/contas-e-tutores.md#convite). The
-- send-invite Edge Function writes invited_at with the service key each time
-- it sends one, to space out resends. Safe to run more than once.

alter table public.pet_tutors
  add column if not exists invited_at timestamptz;
