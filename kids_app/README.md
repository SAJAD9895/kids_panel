# kids_app

The children's app and the mobile Parents Area (Flutter: Android, iOS, web).

```bash
flutter run -d chrome                                 # demo mode (no backend), email code 123456
flutter run --dart-define-from-file=env/dev.json      # against your Supabase dev project
flutter analyze && flutter test
python3 tool/gen_tokens.py                            # after changing docs/design/tokens
```

Docs: `../docs/flutter/` (architecture, environments, auth and child profiles, testing).
Never put the Supabase secret key or database URL in this app or its env files.
