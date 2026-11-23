# Web platform: deployment guide

Phase 15, 2026-11-21. `web_app/` deploys on its own, separately from `admin_panel/`, on a different domain (for example `app.<domain>`, with the admin at `admin.<domain>`).

## 1. Requirements

- Node.js 20 or newer.
- The existing Supabase project, with every migration applied and the Edge Functions `onboarding`, `children`, `play`, `progress` and `account` deployed. **Deploy the current versions**: older builds of `play`, `children` and `account` sent their JSON parameters double-encoded (fixed in Phase 14).
- No new migration is needed for the web.

## 2. Configuration

Only two public values. **Never** set a service-role key, a secret key or a database URL for this app; it refuses to start with a service or secret key.

```bash
NEXT_PUBLIC_SUPABASE_URL=https://<project-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=<publishable or anon key>
```

These are built into the browser code at build time, so set them **before `npm run build`** and rebuild when they change.

## 3. Supabase settings (dashboard, once)

| setting | value |
| --- | --- |
| Auth → URL configuration → Site URL | `https://app.<domain>` |
| Auth → Redirect URLs | `https://app.<domain>/auth/callback` (magic links, PKCE) |
| Auth → Email | OTP length 6, expiry 10 min (as in `docs/backend/authentication.md`). The email templates already include the 6-digit code |
| Auth → Password | minimum 10 characters, with letters and digits |
| Storage | `public-assets` public; `video`, `content` and `exports` private (signed URLs come from the Edge Functions) |
| Custom SMTP | needed before real users: the built-in sender is rate-limited |

## 4. Build and run

```bash
cd web_app
npm ci
npm run build        # runs `npm run sync` first (design tokens → theme.css, engine schema)
npm start            # port 3200 by default
```

**Any Node host works:** Vercel, Netlify, Fly or a container. On Vercel the project root is `web_app/`, the build command is `npm run build`, and the two environment variables go in Production and Preview.

**Health check:** `GET /api/health` returns `{ "ok": true }`.

## 5. Security headers (recommended)

Add these to `next.config.ts` (or the host's settings) for production:
- `Content-Security-Policy`: `default-src 'self'; img-src 'self' https://<project-ref>.supabase.co data:; media-src https://<project-ref>.supabase.co; connect-src 'self' https://<project-ref>.supabase.co; font-src 'self'; frame-ancestors 'none'`;
- `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`.

There are no third-party scripts, analytics or fonts to allow. A strict policy fits.

## 6. Before going live

1. Run the test suites (`testing-report.md`) against this build.
2. Repeat the journeys on a **staging Supabase project**: real Auth emails, real Storage, and the deployed Edge Functions. The automated suite runs against a local stand-in (`testing-report.md` §2).
3. Check the email templates send the code and the link to the right domain.
4. Turn on the headers in §5.
5. Run `scripts/check-secrets.sh` (from the repository root).

## 7. Running it locally without a Supabase project

```bash
cd web_app
node test/stack/stack.mjs          # prints NEXT_PUBLIC_SUPABASE_URL and the key for a local stack
# in another terminal, with those two values exported:
npm run dev                        # http://localhost:3200
```

The local stack needs Postgres 17 (`PG_BIN`), `postgrest` and `deno`. Sign in as `alice@example.test` / `Parent-pass-123`. Emailed codes are printed by `GET <stack url>/__test/mailbox?email=…`. It is for development only; **never point it at real data**.
