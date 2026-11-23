#!/usr/bin/env bash
# Fails if anything that looks like a secret is in the repository (run in CI and before commits).
# Checks: Supabase secret / service-role keys, JWTs, Stripe live/test secret keys, Postgres URLs
# with passwords, private keys, committed env files, and the service-role key referenced from
# client code (Flutter apps/, Next.js client components).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
EXCL=(--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.dart_tool --exclude-dir=build --exclude-dir=.next
      --exclude=check-secrets.sh --exclude=*.png --exclude=*.jpg --exclude=*.jpeg)
fail=0
hit() { echo "✗ $1"; echo "$2" | sed 's/^/    /' | cut -c1-160; fail=1; }

p='sb_secret_[A-Za-z0-9_-]{10,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|sk_(live|test)_[A-Za-z0-9]{10,}|rk_(live|test)_[A-Za-z0-9]{10,}|whsec_[A-Za-z0-9]{10,}|re_[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
r=$(grep -rnEI "${EXCL[@]}" "$p" . 2>/dev/null); [ -n "$r" ] && hit "secret-looking values" "$r"

r=$(grep -rnEI "${EXCL[@]}" 'postgres(ql)?://[^:@/ ]+:[^@/ ]+@' . 2>/dev/null | grep -vE 'postgres:postgres@(127\.0\.0\.1|localhost)'); [ -n "$r" ] && hit "database URL with a password" "$r"

r=$(find . -path ./node_modules -prune -o -name '.env*' -type f ! -name '.env.example' -print 2>/dev/null); [ -n "$r" ] && hit "env files present (must stay untracked)" "$r"
if [ -f .env.example ] && grep -qE '^[A-Z_]+=[^[:space:]]' .env.example; then hit ".env.example has values" "$(grep -nE '^[A-Z_]+=[^[:space:]]' .env.example)"; fi
grep -qE '^\.env\.\*' .gitignore 2>/dev/null || hit ".gitignore does not exclude .env.*" ""

# client code must never reference the service-role / secret key
for d in kids_app apps/kids_app apps/parent-web apps/admin-web packages; do
  [ -d "$d" ] || continue
  # A line may opt out with the marker `secret-scan: allow` (code that DETECTS a leaked key).
  r=$(grep -rnEI "${EXCL[@]}" 'SERVICE_ROLE|SUPABASE_SECRET_KEY|service_role|SUPABASE_DB_URL' "$d" 2>/dev/null | grep -v 'secret-scan: allow'); [ -n "$r" ] && hit "server-only key referenced in client code ($d)" "$r"
  r=$(grep -rnEI "${EXCL[@]}" 'NEXT_PUBLIC_[A-Z_]*(SECRET|SERVICE)' "$d" 2>/dev/null); [ -n "$r" ] && hit "secret exposed through NEXT_PUBLIC_" "$r"
done

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  r=$(git ls-files | grep -E '(^|/)\.env($|\.)' | grep -v '\.env\.example$'); [ -n "$r" ] && hit "env file tracked by git" "$r"
  r=$(git log -p --all 2>/dev/null | grep -nE "$p" | head -5); [ -n "$r" ] && hit "secret in git history" "$r"
else
  echo "! not a git repository yet: history check skipped (run git init, then re-run)"
fi
[ $fail -eq 0 ] && echo "✓ no secrets found" ; exit $fail
