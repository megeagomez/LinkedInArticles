#!/usr/bin/env python
"""Static (offline) syntax validation for a rendered dimension script.

This is the mandatory baseline check the skill runs after every render,
*before* asking whether the user also wants a real test against a live
target (see references/testing.md). It never touches a network, a
workspace, a warehouse, or a lakehouse — everything here is local text
analysis, so it always applies, no confirmation needed.

What it actually checks, per --origin (be honest about the limits — this is
not a substitute for the engine that will really run the code):

  pyspark  Real check: ast.parse() the rendered file. Python syntax errors
           are caught for certain (unbalanced brackets, bad indentation,
           bad f-strings, etc.). This is the only origin with a true local
           parser available.

  fabric   Heuristic only: TMDL has no offline parser available in this
  m        environment, and neither does Power Query M. Both just check
           that (), [] and {} are balanced — note M itself uses "{{ }}"
           for list-of-lists literals, so this is a weak check by nature.
           A clean result here means "no obvious structural breakage", not
           "this will run without error" — TMDL needs Tabular Editor / the
           Fabric API to really validate, M needs the Power Query engine
           (see the "real test" option instead).

  sql      Heuristic only: same bracket-balance check, plus a check that
           DECLARE and CREATE TABLE are both present (the two statements
           the template always emits). No local T-SQL parser is used —
           a real syntax check needs the Fabric Warehouse engine itself.

Usage:
    python render_pyspark.py ... | python validate_syntax.py --origin pyspark
    python validate_syntax.py --origin sql --file rendered.sql
"""
import argparse
import ast
import sys

_PAIRS = {"(": ")", "[": "]", "{": "}"}
_CLOSERS = {v: k for k, v in _PAIRS.items()}


def check_balance(text: str) -> list[str]:
    stack = []
    problems = []
    for i, ch in enumerate(text):
        if ch in _PAIRS:
            stack.append((ch, i))
        elif ch in _CLOSERS:
            if not stack or stack[-1][0] != _CLOSERS[ch]:
                line = text.count("\n", 0, i) + 1
                problems.append(f"unmatched '{ch}' at line {line}")
                continue
            stack.pop()
    for ch, i in stack:
        line = text.count("\n", 0, i) + 1
        problems.append(f"unclosed '{ch}' opened at line {line}")
    return problems


def validate(origin: str, text: str) -> tuple[bool, list[str]]:
    if origin == "pyspark":
        try:
            ast.parse(text)
        except SyntaxError as exc:
            return False, [f"Python SyntaxError: {exc.msg} (line {exc.lineno})"]
        return True, ["ast.parse() succeeded — this is valid Python."]

    problems = check_balance(text)

    if origin == "sql":
        if "DECLARE" not in text:
            problems.append('expected "DECLARE" not found — template may not have rendered fully')
        if "CREATE TABLE" not in text:
            problems.append('expected "CREATE TABLE" not found — template may not have rendered fully')
        note = "heuristic bracket-balance + keyword-presence check only, not a real T-SQL parse"
    elif origin in ("fabric", "m"):
        note = "heuristic bracket-balance check only, not a real TMDL/M parse"
    else:
        return False, [f"unknown origin {origin!r}"]

    if problems:
        return False, problems
    return True, [f"bracket balance OK ({note})"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--origin", required=True, choices=["m", "sql", "fabric", "pyspark"])
    parser.add_argument("--file", help="read from this file instead of stdin")
    args = parser.parse_args()

    text = pathlib_read(args.file) if args.file else sys.stdin.read()
    ok, messages = validate(args.origin, text)
    for m in messages:
        print(("OK: " if ok else "PROBLEM: ") + m)
    sys.exit(0 if ok else 1)


def pathlib_read(path: str) -> str:
    import pathlib
    return pathlib.Path(path).read_text(encoding="utf-8")


if __name__ == "__main__":
    main()
