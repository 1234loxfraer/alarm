#!/usr/bin/env python3
"""Parse JJS wiki character pages into structured JSON (abilities per tab)."""
import json
import os
import re
import sys

RAW = os.path.join(os.path.dirname(__file__), "raw")

CHARS = [
    "Honored One", "Vessel", "Restless Gambler", "Ten Shadows", "Mahoraga", "Perfection",
    "Blood Manipulator", "Switcher", "Defense Attorney", "Cursed Partners", "Puppet Master",
    "Head of the Hei", "Salaryman", "Disaster Plants", "True Cannon", "Register", "Sky Assassin",
    "Locust Guy", "Star Rage", "Aspiring Mangaka", "Lucky Coward", "Crow Charmer", "Black Death",
    "Strongest Of History", "Monkey Kid", "Super TZE", "Mokou", "Cursed Child",
]

SKIP_TABS = {"Finishers"}


def find_templates(text, name):
    """Yield the inner text of every {{name ...}} template, handling nesting."""
    out = []
    i = 0
    pat = re.compile(r"\{\{\s*" + re.escape(name) + r"\s*\n?\|", re.I)
    while True:
        m = pat.search(text, i)
        if not m:
            break
        depth = 0
        j = m.start()
        while j < len(text):
            if text.startswith("{{", j):
                depth += 1
                j += 2
                continue
            if text.startswith("}}", j):
                depth -= 1
                j += 2
                if depth == 0:
                    break
                continue
            j += 1
        out.append((m.start(), text[m.end() - 1:j - 2]))
        i = j
    return out


def split_fields(body):
    """Split a template body on top-level '|' into key=value fields."""
    fields = []
    depth_c = depth_s = 0
    cur = ""
    i = 0
    while i < len(body):
        c2 = body[i:i + 2]
        if c2 == "{{":
            depth_c += 1
            cur += c2
            i += 2
            continue
        if c2 == "}}":
            depth_c -= 1
            cur += c2
            i += 2
            continue
        if c2 == "[[":
            depth_s += 1
            cur += c2
            i += 2
            continue
        if c2 == "]]":
            depth_s -= 1
            cur += c2
            i += 2
            continue
        if body[i] == "|" and depth_c == 0 and depth_s == 0:
            fields.append(cur)
            cur = ""
            i += 1
            continue
        cur += body[i]
        i += 1
    fields.append(cur)
    res = {}
    for f in fields:
        if "=" in f:
            k, v = f.split("=", 1)
            res[k.strip()] = v.strip()
    return res


def clean(s):
    s = re.sub(r"\[\[File:[^\]]*\]\]", "", s)
    s = re.sub(r"\[\[(?:[^|\]]*\|)?([^\]]*)\]\]", r"\1", s)
    s = re.sub(r"\{\{WdsTooltips[^}]*\}\}", "", s)
    # {{Char Name}} style shortcut templates -> their name
    s = re.sub(r"\{\{([^{}|]+?)(?:fanmade)?(?:Icon|icon|Link|Shortcut)?\}\}", lambda m: m.group(1).strip(), s)
    s = re.sub(r"\{\{[^{}]*\}\}", "", s)
    s = re.sub(r"<br\s*/?>", "\n", s)
    s = re.sub(r"<[^>]+>", "", s)
    s = s.replace("'''", "").replace("''", "")
    s = s.replace("&nbsp;", " ")
    s = re.sub(r"[ \t]+", " ", s)
    s = re.sub(r"\n\s*\n+", "\n", s)
    return s.strip()


FLAG_KEYS = [
    "Blockable", "Unblockable", "Semi Blockable", "Perfect Blockable", "360 Blockable",
    "Interruptible", "Uninterruptible", "Bypasses Ragdoll", "Cannot Bypass Ragdoll", "Semi Ragdoll",
    "No Evasive", "No Lock On", "Melee Armor", "Bullet Armor", "Total Armor", "Beam",
]
DMG_KEYS = ["Melee", "Bullet", "Explosion", "Swarm", "Domain"]


def parse_ability(body):
    f = split_fields(body)
    ab = {
        "name": clean(f.get("Name", "")).strip('"').strip() if False else clean(f.get("Name", "")),
        "type": clean(f.get("Type", "")),
        "flags": [],
        "dmg": [],
        "stats": [],
        "desc": clean(f.get("Description", "")),
    }
    for k in FLAG_KEYS:
        if f.get(k, "").lower().startswith("y"):
            ab["flags"].append(k)
    for k in ["Uniterruptible"]:
        if f.get(k, "").lower().startswith("y"):
            ab["flags"].append("Uninterruptible")
    for k in ["Cannot Bypass Ragdol", "Cannot Bypa Ragdoll"]:
        if f.get(k, "").lower().startswith("y"):
            ab["flags"].append("Cannot Bypass Ragdoll")
    for k in DMG_KEYS:
        if f.get(k, "").lower().startswith("y"):
            ab["dmg"].append(k)
    for n in range(1, 7):
        k = f.get("Stat %d" % n)
        if k:
            ab["stats"].append([clean(k).upper(), clean(f.get("Stat %d Value" % n, ""))])
    return ab


def parse_page(title):
    path = os.path.join(RAW, title.replace(" ", "_").replace("/", "_") + ".wiki")
    text = open(path, encoding="utf-8").read()
    info = {}
    for body in find_templates(text, "Character2"):
        f = split_fields(body[1])
        info = {k: clean(v) for k, v in f.items() if k in ("hp", "awakening", "special", "cost")}
        break

    m = re.search(r"^==\s*Moves(?:et)?\s*==\s*$", text, re.M)
    if not m:
        return {"title": title, "info": info, "tabs": {}}
    rest = text[m.end():]
    end = re.search(r"^==[^=].*==\s*$", rest, re.M)
    section = rest[:end.start()] if end else rest

    tabs = {}
    parts = re.split(r"^\|-\|([^=\n]+)=\s*$", section, flags=re.M)
    if len(parts) == 1:
        parts = ["", "Base", section]
    for i in range(1, len(parts), 2):
        name = parts[i].strip()
        if name in SKIP_TABS:
            continue
        abilities = [parse_ability(b) for _, b in find_templates(parts[i + 1], "Ability")]
        if abilities:
            tabs[name] = abilities
    return {"title": title, "info": info, "tabs": tabs}


def parse_roster():
    """Slot layout from the Characters page: base / awakening move lists."""
    text = open(os.path.join(RAW, "Characters.wiki"), encoding="utf-8").read()
    roster = {}
    for m in re.finditer(r"link=([^\]|]+)\]\]", text):
        title = m.group(1).strip()
        if title not in CHARS or title in roster:
            continue
        start = m.end()
        nxt = re.search(r"^\|-", text[start:], re.M)
        block = text[start:start + (nxt.start() if nxt else 3000)]
        groups = [{"label": "Base", "moves": []}]
        for line in block.split("\n"):
            line = line.strip()
            big = re.match(r"^(?:'''\s*)?<big>\s*(?:''')?(.+?)(?:''')?\s*</big>", line) or \
                re.match(r"^'''<big>(.+?)</big>'''", line)
            if big:
                groups.append({"label": clean(big.group(1)), "moves": []})
                continue
            mv = re.match(r"^\*\s*'''(?:\(([^)]*)\)\s*)?(.+?)'''\s*$", line)
            if mv:
                groups[-1]["moves"].append([mv.group(1) or "", clean(mv.group(2))])
        roster[title] = groups
    return roster


if __name__ == "__main__":
    data = {"roster": parse_roster(), "chars": {}}
    for c in CHARS:
        data["chars"][c] = parse_page(c)
    json.dump(data, open(sys.argv[1] if len(sys.argv) > 1 else "chars.json", "w"), indent=1, ensure_ascii=False)
    for c in CHARS:
        p = data["chars"][c]
        print("%-22s hp=%-5s tabs=%s" % (c, p["info"].get("hp"), {k: len(v) for k, v in p["tabs"].items()}))
