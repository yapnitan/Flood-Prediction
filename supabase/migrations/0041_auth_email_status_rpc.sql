-- The login page's "Confirm email" flow needs to tell three cases apart
-- BEFORE calling auth.resend():
--   * the email was never registered      -> tell the user to sign up
--   * the email is registered, unconfirmed -> resend the code
--   * the email is already confirmed        -> tell the user to log in
--
-- The client can't read auth.users, and public.account only gets a row
-- AFTER confirmation, so "never signed up" and "signed up, not confirmed"
-- are indistinguishable from the app. This SECURITY DEFINER function is the
-- minimal oracle for it: it returns only the three-state string, nothing
-- about the user. (The app already reveals the same distinction today via
-- register()'s "already registered" and resend()'s "already confirmed"
-- messages.)
create or replace function public.auth_email_status(p_email text)
returns text
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  confirmed_at timestamptz;
begin
  select u.email_confirmed_at
  into confirmed_at
  from auth.users u
  where lower(u.email) = lower(trim(p_email))
  order by u.created_at desc
  limit 1;

  -- `found` is plpgsql's row-was-returned flag; a plain "select into" with
  -- no match sets the target vars to NULL rather than leaving a boolean
  -- false, so we can't test the variable itself.
  if not found then
    return 'not_registered';
  elsif confirmed_at is not null then
    return 'confirmed';
  else
    return 'unconfirmed';
  end if;
end;
$$;

revoke all on function public.auth_email_status(text) from public;
grant execute on function public.auth_email_status(text) to anon, authenticated;
