-- Storage buckets and storage.objects policies (docs/architecture/11-media-storage.md §11.1, §11.3)
-- Kids Learning Platform · new in the implementation (the draft documented storage but had no DDL).
--
-- Model: clients never read private media directly. Edge Functions (service role, bypasses RLS)
-- issue short-lived signed URLs after their own checks (play/launch, downloads manifest, exports).
-- So there are NO client policies on content / video / exports, and none on public-assets either:
-- public files are served by public URL without a policy, and leaving out a SELECT policy stops
-- anyone listing the bucket.
--
-- Size limits here are per bucket; the project-wide upload limit (Dashboard → Storage → Settings)
-- must be at least the largest of them (see docs/backend/setup-guide.md).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('public-assets', 'public-assets', true,  10485760,                     -- 10 MB
     array['image/webp','image/png','image/jpeg','application/json']),   -- no SVG: script risk
  ('content',       'content',       false, 209715200,                    -- 200 MB packs
     array['application/zip','audio/mp4','audio/aac','audio/mpeg','image/webp','image/png',
           'application/pdf','application/json','application/octet-stream']),
  ('video',         'video',         false, 1073741824,                   -- 1 GB renditions
     array['application/vnd.apple.mpegurl','application/x-mpegurl','video/mp2t','video/mp4',
           'video/iso.segment','text/vtt']),
  ('exports',       'exports',       false, 1073741824,
     array['application/zip']),
  ('admin-staging', 'admin-staging', false, 2147483648,                   -- 2 GB raw masters
     null)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- admin-staging: an admin with content.write (and MFA, via has_permission) may upload, only under
-- a folder named after their own user id. No read, update or delete for clients:
-- admin/media/finalize (service role) verifies and moves the object.
create policy admin_staging_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'admin-staging'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and private.has_permission('content.write')
  );
