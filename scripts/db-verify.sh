#!/usr/bin/env bash
# Verifies the migrations, seed and RLS tests on a THROWAWAY local Postgres 17 (no Docker needed).
# Creates a temp cluster on a random port, applies: Supabase stub → migrations (in order) → seed →
# tests, then stops and deletes the cluster. Never touches a remote database.
#   usage: scripts/db-verify.sh            (PG_BIN defaults to Homebrew postgresql@17)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PG_BIN="${PG_BIN:-/opt/homebrew/opt/postgresql@17/bin}"
TMP="$(mktemp -d)"; PORT=$(( 54000 + RANDOM % 1000 ))
cleanup() { "$PG_BIN/pg_ctl" -D "$TMP/db" stop -m fast >/dev/null 2>&1 || true; rm -rf "$TMP"; }
trap cleanup EXIT
"$PG_BIN/initdb" -D "$TMP/db" -U postgres -A trust >/dev/null
"$PG_BIN/pg_ctl" -D "$TMP/db" -o "-p $PORT -k '' -c listen_addresses=localhost" -l "$TMP/log" -w start >/dev/null
q() { "$PG_BIN/psql" -h localhost -p "$PORT" -U postgres -X -q -v ON_ERROR_STOP=1 "$@"; }
q -c "create database kl"
run() { echo "→ $1"; q -d kl -f "$1" >/dev/null; }
run "$ROOT/supabase/tests/local/00_supabase_stub.sql"
for f in "$ROOT"/supabase/migrations/*.sql; do run "$f"; done
run "$ROOT/supabase/seed.sql"
for f in "$ROOT"/supabase/tests/*.sql; do echo "→ $f"; q -d kl -f "$f"; done
echo "✓ all migrations, seed and tests passed"
