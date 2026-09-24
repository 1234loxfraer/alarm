#!/usr/bin/env python3
"""Translate GLua to Lua 5.3: `continue` -> goto a label placed at the end of the loop body."""
import re
import sys

KEYWORDS_OPEN = {"function", "if", "do", "for", "while", "repeat"}
TOKEN = re.compile(r"""
    (?P<comment>--\[(?P<eq>=*)\[.*?\](?P=eq)\]|--[^\n]*)
  | (?P<lstr>\[(?P<eq2>=*)\[.*?\](?P=eq2)\])
  | (?P<str>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<other>.)
""", re.S | re.X)


def translate(src):
    out = []
    stack = []  # entries: [kind, loop_id or None, used]
    loop_n = 0
    pending_do_for_loop = False  # after for/while we expect a 'do' that belongs to the loop
    pos = 0
    for m in TOKEN.finditer(src):
        text = m.group(0)
        name = m.group("name")
        if name is None:
            out.append(text)
            continue
        if name in ("for", "while"):
            loop_n += 1
            stack.append(["loop", loop_n, False])
            pending_do_for_loop = True
            out.append(text)
        elif name == "do":
            if pending_do_for_loop:
                pending_do_for_loop = False
            else:
                stack.append(["do", None, False])
            out.append(text)
        elif name == "repeat":
            loop_n += 1
            stack.append(["repeat", loop_n, False])
            out.append(text)
        elif name in ("function", "if"):
            stack.append([name, None, False])
            out.append(text)
        elif name == "end":
            top = stack.pop() if stack else None
            if top and top[0] == "loop" and top[2]:
                out.append("::continue_%d:: " % top[1])
            out.append(text)
        elif name == "until":
            top = stack.pop() if stack else None
            if top and top[2]:
                out.append("::continue_%d:: " % top[1])
            out.append(text)
        elif name == "continue":
            for entry in reversed(stack):
                if entry[0] in ("loop", "repeat"):
                    entry[2] = True
                    out.append("goto continue_%d" % entry[1])
                    break
            else:
                out.append(text)
        else:
            out.append(text)
    return "".join(out)


if __name__ == "__main__":
    src = open(sys.argv[1], encoding="utf-8").read()
    sys.stdout.write(translate(src))
