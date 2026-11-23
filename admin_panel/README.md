# Admin CMS

The staff web app for the kids' learning platform: content (activities, games, quizzes, courses, lessons, media, rewards), publishing workflow, families and data requests, subscriptions (read and plan metadata), admin users, settings, audit log.

It uses the existing Supabase backend with the **admin's own session**. It never holds a service-role key or a database URL. Docs: `../docs/admin-cms/`.

## Set up

```bash
cp .env.example .env.local    # public URL + publishable (anon) key only
npm install
npm run dev                   # http://localhost:3000
```

Supabase project, once:
1. Expose the `admin_api` schema in the Data API.
2. Enable TOTP MFA.
3. Deploy `supabase/functions/admin`.
4. Create the first super admin with SQL.

The details are in `../docs/admin-cms/architecture.md` §6.

## Scripts

| script | does |
| --- | --- |
| `npm run sync` | generates `src/app/theme.css` from the design tokens and copies the game engine's JSON Schema (runs before `dev`, `build` and `test`) |
| `npm run lint`, `npm run typecheck` | ESLint, `tsc --noEmit` |
| `npm test` | Vitest: unit, plus integration against a local stack it starts itself |
| `npm run e2e` | Playwright with system Chrome: builds the app, starts the local stack, runs the browser tests and saves screenshots to `../docs/admin-cms/screens/` |
| `node test/stack/stack.mjs` | keeps a local stack running and prints the two env variables to point `npm run dev` at it |

**The local stack** (`test/stack/`):
- **Needs:** Postgres 17 (`PG_BIN`), `postgrest` and `deno` on the PATH.
- **Real parts:** every migration and the seed, PostgREST, the real `admin` Edge Function.
- **Stubbed parts:** Auth and Storage endpoints. Test-only, with fixed values: sign in with `editor@admin.test` (or `super@`, `manager@`, `support@`, `finance@`, `privacy@`), password `Admin-pass-123`, code `123456`.
- **Never point it at real data.**

The e2e tests also check results directly in the stack's database. Running them against a staging Supabase project means replacing those checks, and creating the same test staff accounts there with real authenticators. Neither has been done yet.
