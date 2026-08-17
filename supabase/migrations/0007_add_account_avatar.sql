-- Profile picture support: an avatar_url column on account, plus a public
-- storage bucket so avatars can be displayed via a plain public URL
-- (no signed-URL/auth-header handling needed on the Flutter side).

alter table public.account
  add column if not exists avatar_url text;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "Users can upload their own avatar" on storage.objects;
drop policy if exists "Users can update their own avatar" on storage.objects;
drop policy if exists "Users can delete their own avatar" on storage.objects;
drop policy if exists "Anyone can view avatars" on storage.objects;

create policy "Users can upload their own avatar"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can update their own avatar"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their own avatar"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Public bucket: anyone (including anonymous) can view avatars via the API,
-- matching the public URL access the bucket already allows.
create policy "Anyone can view avatars"
  on storage.objects
  for select
  to public
  using (bucket_id = 'avatars');
