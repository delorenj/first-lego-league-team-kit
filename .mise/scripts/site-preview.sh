#!/usr/bin/env bash
# Assemble the GitHub Pages layout (site/ → root, apps/web/ → /demo/) and serve it.
# Mirrors .github/workflows/pages.yml so the local preview matches the deploy exactly.
set -euo pipefail

ROOT="${MISE_PROJECT_ROOT:-$(git rev-parse --show-toplevel)}"
OUT="${TMPDIR:-/tmp}/legofirst-site"
PORT="${PORT:-8419}"

rm -rf "$OUT"
mkdir -p "$OUT/demo"
cp -r "$ROOT/site/." "$OUT/"
cp -r "$ROOT/apps/web/." "$OUT/demo/"
rm -f "$OUT/demo/config.js"   # ship the neutral defaults, like CI (config.js is git-ignored)

echo "🧱 assembled → $OUT"
if [ "${1:-serve}" = "build" ]; then exit 0; fi
echo "🧱 serving   → http://localhost:$PORT/   (Ctrl-C to stop)"
python3 -m http.server "$PORT" -d "$OUT"
