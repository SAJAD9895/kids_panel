# Flutter architecture (as built)

Design source: `docs/architecture/02-flutter-architecture.md`. This page records what exists in `kids_app/` and where it differs.

## 1. Folders

```
kids_app/lib/
├── main.dart                         bootstrap(AppConfig.fromEnvironment())
├── app/
│   ├── bootstrap.dart                validate config → Supabase or demo backend → ProviderScope
│   ├── app.dart                      MaterialApp.router; ConfigErrorApp for unsafe builds
│   ├── app_info.dart                 working app name
│   ├── config/app_config.dart        build-time config + secret-key guard
│   ├── providers.dart                repository providers (overridden in bootstrap / tests)
│   ├── session.dart                  resets session state when the parent changes; sign-out
│   └── router/                       routes.dart (paths), guards.dart (pure redirect), app_router.dart
├── core/
│   ├── art/characters.dart           Pip, Bolt, Nova + 12 buddies, drawn in code (original art)
│   ├── clock/clock.dart              injectable "now"
│   ├── error/                        Failure (sealed) + mapError (Supabase errors → Failure)
│   ├── gate/                         parental gate rules (pure Dart) + controller
│   ├── layout/window_class.dart      M3 window classes, phone orientation policy
│   ├── theme/                        tokens.g.dart (GENERATED), app_theme.dart (text styles, Material theme)
│   └── widgets/                      kid controls, grown-up form pieces, loading / error / empty states, page frame
├── demo/demo_backend.dart            in-memory backend (demo mode and tests)
└── features/
    ├── auth/            domain (AuthRepository) · data (Supabase, secure storage) · presentation (sign-up, sign-in, code, re-auth dialog)
    ├── onboarding/      domain (OnboardingRepository) · data · presentation (splash, welcome, finish)
    ├── child_profiles/  domain (ChildProfile, BirthYearMonth, rules) · data · presentation (K05, K06, K35, P02)
    ├── kids_home/       presentation (K07 shell)
    └── parents/         presentation (K20 gate, P01)
```

## 2. Layers

| layer | may import | holds |
| --- | --- | --- |
| domain | Dart only | entities, value objects with their rules (nickname, birth month window, stage), repository interfaces |
| data | domain, Supabase SDK, `core/error` | repository implementations; every SDK error becomes a `Failure` |
| presentation | domain, Riverpod, Flutter, GoRouter | providers, screens, widgets |

`test/unit/architecture_test.dart` fails the build if a domain file imports Flutter, Supabase, Riverpod, GoRouter or a `data/` / `presentation/` file. Use cases were not added: this phase has no logic beyond what the repositories and controllers hold (the architecture doc says "only where there is logic").

## 3. Providers

| provider | kind | lifetime |
| --- | --- | --- |
| `appConfigProvider`, `authRepositoryProvider`, `onboardingRepositoryProvider`, `childProfilesRepositoryProvider`, `timezoneProvider`, `clockProvider` | infrastructure | app; overridden in bootstrap |
| `authStateProvider` (stream), `currentUserIdProvider` | session | app |
| `familyStatusProvider` | session | refetched per user |
| `childrenProvider` (AsyncNotifier: reload, add, edit, remove), `avatarsProvider` | family data | refetched per user |
| `selectedChildIdProvider`, `gateProvider`, `emailCodeProvider`, `consentChoicesProvider`, `childDraftProvider(flow)` | session | reset by `sessionProvider` |
| `onboardingSubmitProvider` | controller | one submit at a time |
| `routerProvider` | infrastructure | listens to session providers to re-run the redirect |

`sessionProvider` watches the user id; any change (sign-out, expired refresh token, another account) invalidates every session provider, so nothing from one family or child reaches the next one. Riverpod's automatic retry is off: repositories already map errors and every screen has "Try again".

## 4. Routing

All paths are in `app/router/routes.dart`. `guards.dart` is one pure function `redirectFor(GuardState, Uri)`, tested table by table:

| session | allowed | otherwise |
| --- | --- | --- |
| restoring | splash | splash |
| signed out | welcome, setup child / buddy / grown-up, sign-in, code | welcome |
| signed in, no family | setup screens; finish only when the child and the required consents are present | the first missing step |
| family, no child chosen | who's playing, gate, Parents Area (with gate) | who's playing |
| family, child chosen | kids, who's playing, gate, Parents Area (with gate) | kids |
| Parents Area without an open gate | — | `/gate?next=<path>` (only `/parents…` paths are accepted as `next`) |

Phone orientation (design README §4): kid screens landscape, grown-up screens portrait, tablets and web free (`OrientationScope`).

## 5. Design system in code

- `tool/gen_tokens.py` generates `lib/core/theme/tokens.g.dart` from `docs/design/tokens/` (colours, space, radius, sizes, breakpoints, motion, shadows, type). Widgets use only these constants. `--check` mode is for CI.
- Four size tokens were added to `tokens.json` for this phase (and the CSS / Tailwind / Flutter outputs regenerated): `tap-kids-xl` 84, `kids-buddy-tile` 128, `kids-art-lg` 220, `ui-form-w` 460.
- Fonts: Fredoka, Nunito, Inter bundled in `assets/fonts` (SIL OFL, licences beside them). Nothing is fetched at runtime. Andika (reading) is not bundled yet.
- Kid controls (`core/widgets/kids_controls.dart`): `KidsButton` (raised pill, sinks when pressed, 4 px focus ring, Enter / Space), `KidsIconButton`, `GrownUpsButton`, `PillChoice`, `SelectableTile`, `StepDots`, `SpeechBubble`, `KidsTagChip`. Minimum target 56–64 dp.
- Grown-up pieces (`core/widgets/grown_up.dart`): `GrownUpZone` (K03 / K04 layout), `GrownUpTag`, `PrimaryButton`, `CheckRow`, `CodeInput` (6 boxes over one real text field: paste and one-time-code autofill work), `FormErrorText`, `GrownUpPage`.
- States (`core/widgets/state_views.dart`): pulsing `Skeleton` (stops when the system asks for reduced motion), `KidsErrorView` (character and "Try again", no error text for children), `GrownUpErrorView`, `EmptyStateView`.
- Art: original characters and buddies drawn with `CustomPainter` from the mockup shapes. Buddies map from the `avatars` table by key (`buddy-04` → art 3) until commissioned images exist.

## 6. Deviations from the architecture doc (and why)

| doc said | built | why |
| --- | --- | --- |
| `apps/kids_app` + shared `packages/dart/kl_*` | `kids_app/` with everything inside | the user asked to use the existing project; packages get split out when a second Dart app needs them |
| Riverpod with `riverpod_generator`, `freezed`, `json_serializable` | plain Riverpod 3 providers and hand-written immutable classes | 6 small entities; no build_runner step for contributors or CI yet. Easy to switch later, nothing in the public API changes |
| `main_dev.dart` / `main_staging.dart` / `main_prod.dart` flavors | one `main.dart` + `--dart-define-from-file=env/<env>.json` | same separation with less code; staging is just another env file |
| `Result<T, Failure>` from repositories | repositories throw a sealed `Failure`; controllers expose `AsyncValue` | `AsyncValue.guard` already gives the Result shape; one less wrapper |
| `EdgeClient` with `X-Child-Id`, `X-Request-Id`, retries | Supabase SDK `functions.invoke` | no child-scoped route exists yet; add the client with the play routes (M2) |
| Drift, Sentry, l10n ARB files | not added | not needed by these screens; copy is English in code until the l10n step |
