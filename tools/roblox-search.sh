#!/usr/bin/env bash
# Look up game names in Roblox's own public search and print what already exists.
# Usage: tools/roblox-search.sh [--all] "carve a statue" "guide a ship" ...
#   --all  list every result title instead of a short summary
# Read-only: a few GETs per name against the same search the Roblox website uses.
set -u
export SHOW_ALL=0
if [ "${1:-}" = "--all" ]; then SHOW_ALL=1; shift; fi
session=$(python3 -c 'import uuid; print(uuid.uuid4())')
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for q in "$@"; do
  : > "$tmp/pages"
  token=""
  for page in $(seq 1 "${PAGES:-3}"); do
    args=(--data-urlencode "searchQuery=$q" --data-urlencode "sessionId=$session" --data-urlencode "pageType=all")
    [ -n "$token" ] && args+=(--data-urlencode "pageToken=$token")
    curl -sS -m 25 -G "https://apis.roblox.com/search-api/omni-search" "${args[@]}" > "$tmp/body" 2>&1
    cat "$tmp/body" >> "$tmp/pages"; echo >> "$tmp/pages"
    token=$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("nextPageToken") or "")
except Exception: print("")' "$tmp/body")
    [ -z "$token" ] && break
    sleep 0.6
  done
  QUERY="$q" python3 - "$tmp/pages" <<'PY'
import json, os, re, sys
q = os.environ["QUERY"]
show_all = os.environ.get("SHOW_ALL") == "1"
games, errors = [], []
for line in open(sys.argv[1]):
    line = line.strip()
    if not line:
        continue
    try:
        data = json.loads(line)
    except Exception:
        errors.append(line[:200])
        continue
    if "searchResults" not in data:
        errors.append(line[:200])
    for group in data.get("searchResults", []):
        if group.get("contentGroupType") == "Game":
            games.extend(group.get("contents", []))

def norm(s):
    s = re.sub(r"\[[^\]]*\]|\([^)]*\)", " ", s.lower())
    return " ".join(re.sub(r"[^a-z0-9 ]", " ", s).split())

def stem(w):
    return w[:-1] if w.endswith("s") and len(w) > 3 else w

target = norm(q)
words = {stem(w) for w in target.split()} - {"a", "an", "the"}
exact = [g for g in games if norm(g.get("name", "")) == target]
close = [g for g in games if g not in exact and words
         and words <= {stem(w) for w in norm(g.get("name", "")).split()}]
print(f"## {q}: {len(games)} results | {len(exact)} exact title | {len(close)} with all the words")
for e in errors[:2]:
    print(f"  ERROR {e}")

def show(tag, g):
    up, down = g.get("totalUpVotes", 0), g.get("totalDownVotes", 0)
    rating = f"{100 * up // (up + down)}%" if up + down else "n/a"
    name, playing = g.get("name"), g.get("playerCount")
    print(f"  {tag} {name!r} | playing {playing} | rating {rating} ({up + down} votes)")

for g in exact:
    show("EXACT", g)
for g in close[:8]:
    show("CLOSE", g)
rest = [g for g in games if g not in exact and g not in close]
for g in (rest if show_all else rest[:4]):
    show("other", g)
print()
PY
  sleep 0.6
done
