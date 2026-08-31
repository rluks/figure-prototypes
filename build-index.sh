#!/usr/bin/env bash
# Regenerates index.html — a plain text list of links to every prototype HTML file.
#
# Usage:  ./build-index.sh
#
# Add an .html file anywhere in the repo, re-run this, done.

set -euo pipefail
cd "$(dirname "$0")"

OUT="index.html"

esc()    { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }
urlenc() { sed -e 's/%/%25/g' -e 's/ /%20/g' -e 's/#/%23/g' -e 's/?/%3F/g'; }

{
  echo '<!DOCTYPE html>'
  echo '<meta charset="utf-8">'
  echo '<title>Figure Prototypes</title>'
  echo '<h1>Figure Prototypes</h1>'

  find . -name '*.html' -not -path './.git/*' | sort | while IFS= read -r f; do
    rel="${f#./}"
    [ "$rel" = "$OUT" ] && continue
    # Storybook builds ship an iframe.html beside index.html; only index.html is a page to open.
    [ "$(basename "$rel")" = "iframe.html" ] && continue
    printf '<p><a href="%s">%s</a></p>\n' \
      "$(printf '%s' "$rel" | urlenc | esc)" \
      "$(printf '%s' "$rel" | esc)"
  done
} > "$OUT"

echo "Wrote $OUT"
