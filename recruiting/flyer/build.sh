#!/usr/bin/env bash
# Render flyer.html -> lego-league-flyer.pdf using headless Chrome.
#
# The HTML is the SOURCE OF TRUTH for the flyer. Never hand-edit the PDF — edit flyer.html
# and re-run this. (Before this existed the PDF was a hand-made artifact with no source, which
# is how it drifted to a stale grade band and a coach count that wasn't true.)
#
#   ./build.sh
#
# Team-specific values (town, grades, cost, URL) come from apps/web/config.js when it exists,
# else apps/web/config.example.js — the same file a coach already edits for the site, so the
# flyer and the site cannot disagree.
#
# The QR in src/ encodes the CLINTON site (lego.delo.sh). A coach deploying elsewhere MUST
# regenerate it for their own signupUrl — a flyer that scans to someone else's page is worse
# than no flyer. See README.md.
set -euo pipefail

cd "$(dirname "$0")"

OUT="lego-league-flyer.pdf"
SRC="flyer.html"

CHROME=""
for c in google-chrome google-chrome-stable chromium chromium-browser; do
  if command -v "$c" >/dev/null 2>&1; then CHROME="$c"; break; fi
done
[ -n "$CHROME" ] || { echo "error: no Chrome/Chromium found (needed to render the PDF)" >&2; exit 1; }

[ -f "$SRC" ] || { echo "error: $SRC not found" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Rendering $SRC -> $OUT (via $CHROME)"
"$CHROME" \
  --headless \
  --disable-gpu \
  --no-sandbox \
  --no-pdf-header-footer \
  --user-data-dir="$TMP" \
  --virtual-time-budget=10000 \
  --print-to-pdf="$OUT" \
  "file://$PWD/$SRC" 2>/dev/null

[ -s "$OUT" ] || { echo "error: render produced no output" >&2; exit 1; }
echo "OK  $OUT  ($(du -h "$OUT" | cut -f1))"
