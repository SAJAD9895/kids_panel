# Environments

The app reads its configuration at **build time** from a JSON file passed with `--dart-define-from-file`. Nothing is read from the network or from a file at runtime.

## 1. Files

| file | tracked | purpose |
| --- | --- | --- |
| `kids_app/env/dev.example.json` | yes | template, empty values |
| `kids_app/env/prod.example.json` | yes | template, empty values |
| `kids_app/env/dev.json`, `prod.json`, `staging.json` | **no** (`.gitignore`) | your values |

```bash
cd kids_app
cp env/dev.example.json env/dev.json      # then fill in SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY
flutter run --dart-define-from-file=env/dev.json
flutter build appbundle --dart-define-from-file=env/prod.json --obfuscate --split-debug-info=build/symbols
flutter build web --dart-define-from-file=env/prod.json
```

| key | value |
| --- | --- |
| `APP_ENV` | `dev` or `prod` |
| `SUPABASE_URL` | `https://<ref>.supabase.co` (http only for a local stack in dev) |
| `SUPABASE_PUBLISHABLE_KEY` | Project Settings › API Keys › **publishable** key (`sb_publishable_…`), or the legacy anon key |
| `AUTH_REDIRECT_URL` | where the magic link returns. Mobile: `io.kidslearning.app://auth/callback`; web: the app's URL + `/auth/callback`. Must be listed in Auth › URL Configuration |
| `ENABLE_APPLE_SIGN_IN`, `ENABLE_GOOGLE_SIGN_IN` | `true` only after the providers are set up with your own keys (setup-guide §4 #3) |
| `TERMS_URL`, `PRIVACY_URL` | your legal pages (placeholders until then) |
| `POLICY_VERSION` | the version recorded with each consent; change it when the terms change materially |

## 2. Safety checks at start-up

`AppConfig.validate()` runs before anything else. If it finds a problem the app shows "This build can't start" with the reason and **does not connect to anything**:

- a secret key (`sb_secret_…`) or a JWT whose role is `service_role` passed as the publishable key;
- a prod build without a URL and key;
- only one of URL and key set;
- an `http://` URL outside a local dev stack.

Also enforced: `test/unit/architecture_test.dart` fails if `lib/` contains a secret key or a Postgres URL, and `scripts/check-secrets.sh` now scans `kids_app/` for server-only key names. The secret key and `SUPABASE_DB_URL` exist only in Edge Function secrets.

## 3. Demo mode

A **dev** build with no `SUPABASE_URL` runs on `lib/demo/demo_backend.dart`: an in-memory backend with the same interfaces and rules as the server (consents required, Basic plan = 1 child, owner-only delete with a 10-minute re-auth window) and the seed's data. A blue note on the code screen shows the code (`123456`), and the Parents Area shows a "Demo mode" banner. Nothing persists after the app closes. A **prod** build can never be in demo mode.

## 4. Platform settings done in this phase

| platform | setting |
| --- | --- |
| Android | `INTERNET` permission in the main manifest (release builds need it); intent filter for `io.kidslearning.app://auth…`; label "Kids Learning" |
| iOS | `CFBundleURLTypes` with scheme `io.kidslearning.app`; display name "Kids Learning" |
| macOS (dev only) | network client entitlement |
| web | default; session in browser storage (authentication.md §2) |

The scheme and bundle ids (`com.kidslearning.*`) are placeholders until the brand step. Still manual: Universal Links / App Links (needs your domain), Apple / Google sign-in setup, signing keys.
