-- Bring recovery-management columns onto repair_request, then drop the duplicate table.
alter table public.repair_request
  add column priority text not null default 'medium',
  add column assigned_helper_id uuid null,
  add column shelter_name text null,
  add column updated_at timestamp with time zone not null default now();

alter table public.repair_request
  add constraint repair_request_helper_id_fkey
    foreign key (assigned_helper_id) references public.account (id) on delete set null;

alter table public.repair_request
  add constraint repair_request_priority_check
    check (priority = any (array['low'::text, 'medium'::text, 'high'::text, 'urgent'::text]));

-- normalize existing status values to lowercase, matching the rest of your schema
update public.repair_request set status = lower(status);
alter table public.repair_request alter column status set default 'pending';

alter table public.repair_request
  add constraint repair_request_status_check
    check (
      status = any (
        array[
          'pending'::text,
          'approved'::text,
          'rejected'::text,
          'assigned'::text,
          'in_progress'::text,
          'completed'::text,
          'cancelled'::text
        ]
      )
    );

create index if not exists idx_repair_request_status on public.repair_request using btree (status);
create index if not exists idx_repair_request_helper on public.repair_request using btree (assigned_helper_id);

-- superseded by repair_request
drop table if exists public.recovery_request;