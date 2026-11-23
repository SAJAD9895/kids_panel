#!/usr/bin/env python3
"""Lints supabase/config.toml against the auth requirements in docs/backend/authentication.md §2.
The hosted project's dashboard must match (setup-guide §4); `supabase config push` syncs it."""
import sys, tomllib, pathlib
cfg = tomllib.loads((pathlib.Path(__file__).resolve().parent.parent / "supabase/config.toml").read_text())
a, e = cfg["auth"], cfg["auth"]["email"]
checks = [
    ("Data API exposes only public", cfg["api"]["schemas"] == ["public"]),
    ("JWT lifetime ≤ 1 h", a["jwt_expiry"] <= 3600),
    ("refresh token rotation on", a["enable_refresh_token_rotation"] is True),
    ("refresh reuse interval ≤ 10 s", a["refresh_token_reuse_interval"] <= 10),
    ("anonymous sign-ins off", a["enable_anonymous_sign_ins"] is False),
    ("password ≥ 10 chars", a["minimum_password_length"] >= 10),
    ("password complexity set", a.get("password_requirements") in ("lower_upper_letters_digits", "lower_upper_letters_digits_symbols")),
    ("email confirmations on", e["enable_confirmations"] is True),
    ("secure email change (both addresses)", e["double_confirm_changes"] is True),
    ("secure password change", e["secure_password_change"] is True),
    ("OTP 6 digits", e["otp_length"] == 6),
    ("OTP expiry ≤ 10 min", e["otp_expiry"] <= 600),
    ("magic-link template has link AND code",
     all(t in (pathlib.Path(__file__).resolve().parent.parent / "supabase/templates/magic-link.html").read_text()
         for t in ("{{ .ConfirmationURL }}", "{{ .Token }}"))),
    ("TOTP MFA enroll + verify", a["mfa"]["totp"]["enroll_enabled"] and a["mfa"]["totp"]["verify_enabled"]),
    ("OAuth secrets via env()", all(str(a["external"][p]["secret"]).startswith("env(") for p in ("apple", "google"))),
    ("OAuth nonce check on", all(a["external"][p]["skip_nonce_check"] is False for p in ("apple", "google"))),
    ("sign-in rate limit set", a["rate_limit"]["sign_in_sign_ups"] <= 30),
]
bad = [n for n, ok in checks if not ok]
for n, ok in checks: print(("✓ " if ok else "✗ ") + n)
sys.exit(1 if bad else 0)
