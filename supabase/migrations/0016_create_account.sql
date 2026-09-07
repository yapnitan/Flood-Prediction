-- The `account` table itself was never captured in a migration (every prior
-- migration only *references* it as a foreign-key target, e.g.
-- flood_simulation.account_id / flood_report.reporter_id / repair_request
-- .requester_id). It already exists on the live project — this migration
-- documents its schema for fresh environments (`create table if not exists`
-- is a safe no-op against the live DB) and, more importantly, adds the RLS
-- policies + trigger it has never had.
--
-- Without this, any authenticated client could call the Supabase REST API
-- directly and set its own `role`/`status`/`is_active` — since
-- UserManagementService/AuthService enforce nothing client-side and rely
-- entirely on RLS (see their doc comments). That's a real hole in the
-- "helper accounts need admin approval" requirement: a helper sign-up could
-- otherwise just set its own status to 'active' and skip approval entirely.

create table if not exists public.account (
  id uuid primary key references auth.users(id) on delete cascade,

  name text not null default '',
  email text not null,
  role text not null default 'user',

  is_active boolean not null default true,
  status text not null default 'active',

  notify_email boolean not null default true,
  notify_push boolean not null default true,

  avatar_url text,

  created_at timestamptz not null default now()
);

alter table public.account enable row level security;

-- ---- select ----

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'account'
      and policyname = 'Users can view own account'
  ) then
    create policy "Users can view own account"
      on public.account
      for select
      to authenticated
      using (auth.uid() = id);
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'account'
      and policyname = 'Admins can view all accounts'
  ) then
    create policy "Admins can view all accounts"
      on public.account
      for select
      to authenticated
      using (
        exists (
          select 1 from public.account a
          where a.id = auth.uid() and a.role = 'admin'
        )
      );
  end if;
end;
$$;

-- ---- insert ----
-- A signed-up user may only create the row matching their own auth id, and
-- may only ever insert as 'user' or 'helper' (never 'admin' — admin accounts
-- are only created by an existing admin promoting a user's role via
-- UserManagementService.updateRole). A 'helper' row must start 'pending';
-- anything else must start 'active' — this is what actually enforces "helper
-- accounts need admin approval", not just the app UI.

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'account'
      and policyname = 'Users can create their own account'
  ) then
    create policy "Users can create their own account"
      on public.account
      for insert
      to authenticated
      with check (
        auth.uid() = id
        and role in ('user', 'helper')
        and is_active = true
        and status = case when role = 'helper' then 'pending' else 'active' end
      );
  end if;
end;
$$;

-- ---- update ----
-- Row-level access: owners can update their own row, admins can update any
-- row. Column-level protection (a non-admin can't grant themselves 'admin'
-- or flip their own status/is_active) is enforced by the trigger below,
-- since RLS's `with check` alone can't compare against the pre-update row.

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'account'
      and policyname = 'Users can update own account'
  ) then
    create policy "Users can update own account"
      on public.account
      for update
      to authenticated
      using (auth.uid() = id)
      with check (auth.uid() = id);
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'account'
      and policyname = 'Admins can update any account'
  ) then
    create policy "Admins can update any account"
      on public.account
      for update
      to authenticated
      using (
        exists (
          select 1 from public.account a
          where a.id = auth.uid() and a.role = 'admin'
        )
      )
      with check (true);
  end if;
end;
$$;

-- ---- delete ----

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'account'
      and policyname = 'Admins can delete accounts'
  ) then
    create policy "Admins can delete accounts"
      on public.account
      for delete
      to authenticated
      using (
        exists (
          select 1 from public.account a
          where a.id = auth.uid() and a.role = 'admin'
        )
      );
  end if;
end;
$$;

-- ---- privilege-escalation guard ----
-- Blocks changes to role/status/is_active on someone else's — or your own —
-- row unless the caller's own account has role = 'admin'. This runs in
-- addition to the RLS policies above (which only decide *which rows* an
-- update statement may touch, not which *columns* may change).

create or replace function public.prevent_account_privilege_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_is_admin boolean;
begin
  select (role = 'admin') into caller_is_admin
  from public.account
  where id = auth.uid();

  if coalesce(caller_is_admin, false) then
    return new;
  end if;

  if new.role is distinct from old.role
     or new.status is distinct from old.status
     or new.is_active is distinct from old.is_active then
    raise exception 'Only an admin can change role, status, or is_active';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_prevent_account_privilege_escalation on public.account;

create trigger trg_prevent_account_privilege_escalation
  before update on public.account
  for each row
  execute function public.prevent_account_privilege_escalation();
