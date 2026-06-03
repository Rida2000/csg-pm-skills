#!/usr/bin/env bash
# prototype-to-prd — compose a side-by-side BEFORE | AFTER image.
# Usage: compose_before_after.sh <before.png> <after.png> <out.png>
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <before.png> <after.png> <out.png>" >&2
  exit 2
fi
before="$1"; after="$2"; out="$3"

for f in "$before" "$after"; do
  [ -f "$f" ] || { echo "missing input: $f" >&2; exit 1; }
done

# Prefer ImageMagick v7 (magick), fall back to v6 (montage).
if command -v magick >/dev/null 2>&1; then
  MONTAGE=(magick montage)
elif command -v montage >/dev/null 2>&1; then
  MONTAGE=(montage)
else
  echo "ImageMagick not found (need 'magick' or 'montage'). Install it, or compose manually." >&2
  exit 3
fi

# Labeled, two-up tile with padding. Same row, gravity-centered.
"${MONTAGE[@]}" \
  -label 'BEFORE' "$before" \
  -label 'AFTER'  "$after" \
  -tile 2x1 -geometry '+12+12' -background white -bordercolor '#cccccc' -border 1 \
  "$out"

echo "wrote $out"
