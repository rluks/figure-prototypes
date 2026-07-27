#!/usr/bin/env bash
# Regenerates index.html — a browsable list of every prototype HTML file in this repo.
#
# Usage:  ./build-index.sh
#
# Each prototype's label comes from its <title> tag (falling back to the filename),
# its date from the last git commit that touched it (falling back to file mtime).
# Nothing else needs maintaining: add an .html file anywhere, re-run this, done.

set -euo pipefail
cd "$(dirname "$0")"

OUT="index.html"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

esc()    { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }
urlenc() { sed -e 's/%/%25/g' -e 's/ /%20/g' -e 's/#/%23/g' -e 's/?/%3F/g'; }

# Collect: group <TAB> path <TAB> title <TAB> date
while IFS= read -r f; do
  rel="${f#./}"
  [ "$rel" = "$OUT" ] && continue

  title=$(tr '\n' ' ' < "$f" \
          | grep -o -i -m1 '<title>[^<]*</title>' \
          | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || true)
  if [ -z "$title" ]; then
    title=$(basename "$rel" .html)
  fi

  date=$(git log -1 --format=%ad --date=short -- "$rel" 2>/dev/null || true)
  if [ -z "$date" ]; then
    date=$(date -r "$f" +%Y-%m-%d 2>/dev/null || echo "—")
  fi

  case "$rel" in
    */*) group="${rel%%/*}" ;;
    *)   group="Root" ;;
  esac

  printf '%s\t%s\t%s\t%s\n' "$group" "$rel" "$title" "$date"
done < <(find . -name '*.html' -not -path './.git/*' | sort) > "$TMP"

count=$(wc -l < "$TMP" | tr -d ' ')
groups=$(cut -f1 "$TMP" | sort -u | wc -l | tr -d ' ')

{
cat <<'HEAD'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Figure Prototypes</title>
<style>
  :root {
    --bg: #fbfbfa;
    --surface: #ffffff;
    --border: #e4e4e1;
    --text: #1a1a19;
    --muted: #77776f;
    --accent: #2f6fdb;
    --hover: #f4f4f2;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #16161a;
      --surface: #1e1e23;
      --border: #2e2e35;
      --text: #ececef;
      --muted: #93939d;
      --accent: #7aa7f5;
      --hover: #26262d;
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 48px 24px 96px;
    background: var(--bg);
    color: var(--text);
    font: 15px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  .wrap { max-width: 760px; margin: 0 auto; }
  header { margin-bottom: 28px; }
  h1 { margin: 0 0 4px; font-size: 24px; letter-spacing: -0.02em; }
  .sub { margin: 0; color: var(--muted); font-size: 13px; }
  #q {
    width: 100%;
    margin: 24px 0 32px;
    padding: 11px 14px;
    font: inherit;
    color: var(--text);
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
  }
  #q:focus { outline: 2px solid var(--accent); outline-offset: -1px; border-color: transparent; }
  #q::placeholder { color: var(--muted); }
  section { margin-bottom: 32px; }
  h2 {
    margin: 0 0 10px;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.09em;
    text-transform: uppercase;
    color: var(--muted);
  }
  ul { list-style: none; margin: 0; padding: 0; }
  li + li { margin-top: 6px; }
  a.item {
    display: flex;
    gap: 16px;
    align-items: baseline;
    padding: 12px 14px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    text-decoration: none;
    color: inherit;
  }
  a.item:hover { background: var(--hover); border-color: var(--accent); }
  a.item:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
  .name { font-weight: 500; }
  .path {
    display: block;
    margin-top: 2px;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 11.5px;
    color: var(--muted);
    word-break: break-all;
  }
  .meta { flex: 1; min-width: 0; }
  time { flex-shrink: 0; font-size: 12px; color: var(--muted); font-variant-numeric: tabular-nums; }
  #empty { display: none; color: var(--muted); }
  footer { margin-top: 40px; font-size: 12px; color: var(--muted); }
  code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
</style>
</head>
<body>
<div class="wrap">
<header>
  <h1>Figure Prototypes</h1>
HEAD

printf '  <p class="sub">%s prototypes across %s folders</p>\n' "$count" "$groups"

cat <<'MID'
</header>

<input id="q" type="search" placeholder="Filter by name, folder or filename…" autocomplete="off" autofocus>

MID

current=""
while IFS=$'\t' read -r group rel title date; do
  if [ "$group" != "$current" ]; then
    [ -n "$current" ] && printf '  </ul>\n</section>\n\n'
    printf '<section>\n  <h2>%s</h2>\n  <ul>\n' "$(printf '%s' "$group" | esc)"
    current="$group"
  fi
  printf '    <li><a class="item" href="%s"><span class="meta"><span class="name">%s</span><span class="path">%s</span></span><time>%s</time></a></li>\n' \
    "$(printf '%s' "$rel" | urlenc | esc)" \
    "$(printf '%s' "$title" | esc)" \
    "$(printf '%s' "$rel" | esc)" \
    "$(printf '%s' "$date" | esc)"
done < "$TMP"
[ -n "$current" ] && printf '  </ul>\n</section>\n\n'

cat <<FOOT
<p id="empty">No prototypes match that filter.</p>

<footer>Generated $(date +%Y-%m-%d) by <code>./build-index.sh</code> — re-run it after adding a prototype.</footer>
</div>

<script>
  const q = document.getElementById('q');
  const empty = document.getElementById('empty');
  q.addEventListener('input', () => {
    const term = q.value.trim().toLowerCase();
    let hits = 0;
    document.querySelectorAll('section').forEach(section => {
      let shown = 0;
      section.querySelectorAll('li').forEach(li => {
        const match = li.textContent.toLowerCase().includes(term);
        li.hidden = !match;
        if (match) shown++;
      });
      section.hidden = shown === 0;
      hits += shown;
    });
    empty.style.display = hits ? 'none' : 'block';
  });
</script>
</body>
</html>
FOOT
} > "$OUT"

echo "Wrote $OUT — $count prototypes, $groups folders."
