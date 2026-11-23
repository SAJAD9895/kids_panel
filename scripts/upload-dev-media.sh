#!/usr/bin/env bash
# Uploads the development media library (kids_app/assets/dev_media/<bucket>/<path>) to the
# linked Supabase project's Storage, at the paths seed §16 registers in media_assets.
#
#   supabase link --project-ref <your dev project>   # once; you sign in, no keys in this repo
#   scripts/upload-dev-media.sh                       # then this
#
# Uses the Supabase CLI's storage commands with your own login. Never run against production:
# these are development files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/kids_app/assets/dev_media"
command -v supabase >/dev/null || { echo "install the Supabase CLI first"; exit 1; }
count=0
while IFS= read -r -d '' f; do
  rel="${f#"$SRC"/}"            # <bucket>/<path>
  [[ "$rel" == manifest.json ]] && continue
  supabase --experimental storage cp "$f" "ss:///$rel" --linked >/dev/null
  count=$((count + 1))
done < <(find "$SRC" -type f -print0)
echo "uploaded $count files"
