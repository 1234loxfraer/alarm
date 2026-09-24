#!/bin/bash
# Downloads the wikitext of every page of the Jujutsu Shenanigans wiki into tools/wiki/raw/
# and parses the character pages into tools/wiki/chars.json (see parse.py / show.py).
#   tools/wiki/fetch.sh && python3 tools/wiki/show.py "Vessel"
W=$(cd "$(dirname "$0")" && pwd)
API="https://jujutsu-shenanigans.fandom.com/api.php"
mkdir -p "$W/raw"
curl -sS "$API?action=query&list=allpages&aplimit=500&apfilterredir=nonredirects&format=json" \
  | python3 -c "import sys,json; [print(p['title']) for p in json.load(sys.stdin)['query']['allpages']]" > "$W/raw/pages.txt"
while IFS= read -r t; do
  curl -sS -G "$API" --data-urlencode "action=parse" --data-urlencode "page=$t" --data-urlencode "prop=wikitext" \
    --data-urlencode "format=json" --data-urlencode "formatversion=2" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('parse',{}).get('wikitext',''))" > "$W/raw/$(echo "$t" | tr ' /' '__').wiki"
done < "$W/raw/pages.txt"
python3 "$W/parse.py" "$W/chars.json"
