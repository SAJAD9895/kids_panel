# Media management

Phase 14, 2026-11-21. Page `/media`, component `src/components/uploader.tsx`, server route `supabase/functions/admin` → `POST /admin/media/finalize`.

## 1. Secure upload (two steps)

```
1. browser  → Storage  admin-staging/<admin user id>/<uuid>-<name>     (the admin's own session)
               policy: only content.write + aal2, only your own folder (Phase 5 storage migration)
2. server   → POST /functions/v1/admin/media/finalize { stagingPath, width?, height?, durationMs?, locale? }
   Edge Function (service role, server-side only):
   ├─ JWT valid, aal2, admin_can(content.write); the path starts with the caller's id, no ".."
   ├─ download from staging; detect the REAL type from the file's first bytes (not its name or
   │  the browser's claim): PNG, JPEG, WebP, MP4, M4A, MP3, WebVTT, PDF, JSON/zip packs
   ├─ type must be in media.allowed_types, size ≤ media.max_upload_mb   (System settings)
   ├─ SHA-256; store at <bucket>/admin/<YYYY-MM>/<uuid>/<clean name>; delete the staging copy
   └─ private.admin_register_media → media_assets row (status ready, created_by = the admin)
```

**Buckets.**

| bucket | holds | how it's served |
| --- | --- | --- |
| `public-assets` | images | a CDN URL, because images are public |
| `video` | MP4 and WebVTT captions | short-lived signed links through `play/launch` (Phase 11) |
| `content` | audio, packs, PDFs | short-lived signed links through `play/launch` |

**Checks before upload.** The browser rejects obviously wrong files first (type, size, and names with `..` or slashes; `checkUpload`, unit-tested). The server repeats every check. A file that fails is deleted from staging.

**Tested.**
- An upload by an editor works.
- These are refused: another admin's folder, a file disguised as a PNG, a session without MFA, and a support agent (no `content.write`).
- An end-to-end upload in the browser works.

All of these are listed in `testing-report.md`.

## 2. The library

- **Search** by path, and **filter** by kind and status. The list is paginated.
- Each file shows its kind, size, dimensions or duration, language and status.
- **Metadata editing:** language (for captions and narration). Retire a file (status `retired`) instead of deleting it, so content that uses it doesn't break. Retiring a `ready` file that's attached to content needs `content.publish` (the live-content guard).

## 3. Attaching media to content (activity page → Media)

| role | for |
| --- | --- |
| `video_main` | educational videos |
| `audio_main` | children's songs, audio stories |
| `subtitle` | captions (WebVTT) per language. A caption file is also the **transcript** |
| `cover` | thumbnails and artwork (also each activity's thumbnail field) |
| `page_image`, `page_audio` | illustrated story pages (order, and the words on each page) |
| `printable_pdf` | printables |

The brief's media types map to activity types:
- videos → `video`
- songs → `song`
- audio stories → `audio_story`
- illustrated stories → `story`

Each has its own publishing checks (`content-management.md` §2), and each is published through the same workflow as games. **Course thumbnails, category icons and badge art** are chosen from the library's ready images.

## 4. Publishing controls

A file doesn't become visible by itself. The **activity** decides visibility:
- Families only get signed links for media attached to **published** activities they're allowed to open (age, Plus, the parent's section and category switches, screen time; `private.launch`, Phase 11).
- Media on drafts are never served to families.

## 5. Not done

- **No transcoding or thumbnail generation.** Upload the MP4, the poster image and the captions you want to serve. Media processing (multiple renditions, HLS) is a separate pipeline, not part of this phase.
- **Large videos.** The upload is a single request. The limit is the `media.max_upload_mb` setting (200 MB by default; the `admin-staging` bucket itself allows 2 GB). Resumable (TUS) upload isn't wired yet, so very large files depend on the connection.
- **Virus scanning** isn't connected. The magic-byte check refuses executables disguised as media, but it isn't a malware scan.
