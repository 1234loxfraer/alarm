#!/bin/bash
# Headless test run: translates the gamemode to Lua 5.3 (GLua `continue` -> goto) and runs
# tools/harness/run.lua on the GMod API mock in both realms. Every character's moves, variants,
# awakening, M1s, dashes, domains, beam clash, dummies, HUD, effects and the menu are exercised.
#   tools/harness/test.sh [character id]
# Needs: python3, lua5.3.
H=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$H/../.." && pwd)
OUT=$(mktemp -d)
( cd "$SRC/gamemode" && find . -name '*.lua' ) | while read -r f; do
  mkdir -p "$OUT/$(dirname "$f")"
  python3 "$H/glua2lua.py" "$SRC/gamemode/$f" > "$OUT/$f"
done
echo "== server"; ( cd "$H" && REALM=server lua5.3 run.lua "$OUT" $1 2>&1 | grep -v "^	" )
echo "== client"; ( cd "$H" && REALM=client lua5.3 run.lua "$OUT" 2>&1 | grep -v "^	" | tail -5 )
rm -rf "$OUT"
