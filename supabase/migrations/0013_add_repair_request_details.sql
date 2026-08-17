alter table public.repair_request
  add column if not exists details jsonb not null default '{}'::jsonb;

alter table public.repair_request
  alter column damage_description drop not null;
