#!/usr/bin/env python3
"""Inventory literal values in priv/static/styles.css.

Prints JSON: one record per distinct value in each category, with the
selectors that use it and a count of declarations. Custom properties are
recorded both where they are defined and where var() refers to them.
"""

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CSS_PATH = ROOT / "priv" / "static" / "styles.css"

COLOR_RE = re.compile(
    r"#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b"
    r"|rgba?\([^)]*\)"
    r"|\b(?:white|black|transparent|currentColor|inherit)\b"
)
LENGTH_RE = re.compile(
    r"-?\d*\.?\d+(?:px|rem|em|vh|vw|%)"
)
FAMILY_RE = re.compile(r"font-family\s*:\s*([^;]+);")
WEIGHT_RE = re.compile(r"font-weight\s*:\s*([^;]+);")
SIZE_RE = re.compile(r"font-size\s*:\s*([^;]+);")
LEADING_RE = re.compile(r"line-height\s*:\s*([^;]+);")
RADIUS_RE = re.compile(r"border-radius\s*:\s*([^;]+);")
SHADOW_RE = re.compile(r"box-shadow\s*:\s*([^;]+);")
BREAK_RE = re.compile(r"@media\s*\([^)]*\)")
SPACE_PROPS = (
    "margin",
    "padding",
    "gap",
    "row-gap",
    "column-gap",
    "inset",
    "top",
    "right",
    "bottom",
    "left",
)


def strip_comments(text: str) -> str:
    return re.sub(r"/\*.*?\*/", "", text, flags=re.S)


def split_rules(text: str):
    """Yield (selector, body, media) for each style rule. Nested @media only."""
    i = 0
    n = len(text)
    media = None

    def skip_ws(j):
        while j < n and text[j].isspace():
            j += 1
        return j

    while i < n:
        i = skip_ws(i)
        if i >= n:
            break
        if text[i] == "}":
            media = None
            i += 1
            continue
        start = i
        while i < n and text[i] != "{":
            i += 1
        if i >= n:
            break
        selector = " ".join(text[start:i].split())
        i += 1
        depth = 1
        body_start = i
        while i < n and depth:
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
            i += 1
        body = text[body_start : i - 1]
        if selector.startswith("@media"):
            saved = media
            media = selector
            # Recurse into the media body by splicing a scan.
            yield from scan_block(body, media)
            media = saved
        elif selector.startswith("@"):
            continue
        else:
            yield selector, body, media


def scan_block(body, media):
    # Reuse the top-level scanner on a fragment that is not wrapped.
    text = body
    i = 0
    n = len(text)

    def skip_ws(j):
        while j < n and text[j].isspace():
            j += 1
        return j

    while i < n:
        i = skip_ws(i)
        if i >= n:
            break
        start = i
        while i < n and text[i] != "{":
            i += 1
        if i >= n:
            break
        selector = " ".join(text[start:i].split())
        i += 1
        depth = 1
        body_start = i
        while i < n and depth:
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
            i += 1
        rule_body = text[body_start : i - 1]
        if selector:
            yield selector, rule_body, media


def is_color_property(prop: str) -> bool:
    return prop == "color" or prop.endswith("-color") or prop in (
        "background",
        "border",
        "outline",
        "box-shadow",
        "fill",
        "stroke",
    )


def add(bucket, category, value, where):
    key = (category, normalize(value))
    bucket[key]["value"] = normalize(value)
    bucket[key]["category"] = category
    bucket[key]["uses"].append(where)


def normalize(value: str) -> str:
    value = " ".join(value.split())
    value = re.sub(r",\s*", ", ", value)
    return value.strip().rstrip(";")


def custom_properties(text: str) -> dict:
    props = {}
    for selector, body, _media in split_rules(text):
        if selector != ":root":
            continue
        for prop, value in declarations(body):
            if prop.startswith("--"):
                props[prop] = value
    return props


def expand_vars(value: str, props: dict) -> str:
    def repl(match):
        name = match.group(1).strip()
        return props.get(name, match.group(0))

    previous = None
    current = value
    while current != previous:
        previous = current
        current = re.sub(r"var\(\s*(--[A-Za-z0-9-]+)\s*\)", repl, current)
    return current


def main():
    raw = CSS_PATH.read_text()
    text = strip_comments(raw)
    props = custom_properties(text)
    bucket = defaultdict(lambda: {"uses": []})

    for selector, body, media in split_rules(text):
        where_sel = selector if not media else f"{media} >> {selector}"
        for prop, value in declarations(body):
            where = f"{where_sel} {{ {prop} }}"
            expanded = expand_vars(value, props)
            if prop == "font-family" or prop == "font":
                add(bucket, "font-family", value, where)
            elif prop == "font-size":
                add(bucket, "font-size", value, where)
            elif prop == "font-weight":
                add(bucket, "font-weight", value, where)
            elif prop == "line-height":
                add(bucket, "line-height", value, where)
            elif prop == "border-radius":
                add(bucket, "radius", expanded, where)
            elif prop == "box-shadow":
                add(bucket, "shadow", expanded, where)
            elif prop.startswith("--"):
                add(bucket, "custom-property", f"{prop}: {value}", where)
            elif prop in ("letter-spacing", "max-width", "min-height", "min-width", "width", "height", "opacity", "outline-offset", "z-index") or prop.startswith("transition") or prop.startswith("transform"):
                add(bucket, "other", f"{prop}: {value}", where)
            elif prop in ("border", "border-left", "border-top", "border-right", "border-bottom", "outline") or prop.endswith("-width"):
                for length in LENGTH_RE.findall(value) or re.findall(r"\b0\b", value):
                    add(bucket, "border-width", length, where)
            if prop.split("-")[0] in ("margin", "padding") or prop in SPACE_PROPS or prop == "border-radius":
                lengths = LENGTH_RE.findall(expanded)
                if prop != "border-radius":
                    # Unitless 0 is a spacing value. Radius is recorded above.
                    lengths += [token for token in re.findall(r"(?<![\d.])0(?![\d.])", expanded)]
                    seen = set()
                    for length in lengths:
                        if length in seen:
                            continue
                        seen.add(length)
                        add(bucket, "spacing", length, where)
            for color in COLOR_RE.findall(expanded):
                if color == "inherit" and not is_color_property(prop):
                    continue
                add(bucket, "color", color, where)

    for match in BREAK_RE.finditer(text):
        query = " ".join(match.group(0).split())
        add(bucket, "breakpoint", query, query)

    records = []
    for item in bucket.values():
        uses = item["uses"]
        records.append(
            {
                "category": item["category"],
                "value": item["value"],
                "count": len(uses),
                "where": uses,
            }
        )
    records.sort(key=lambda row: (row["category"], -row["count"], row["value"]))
    if "--markdown" in sys.argv:
        write_markdown(records)
        return
    json.dump({"source": "priv/static/styles.css", "records": records}, sys.stdout, indent=2)
    sys.stdout.write("\n")


def short_where(uses):
    selectors = []
    for use in uses:
        selector = use.split(" {")[0]
        selector = selector.replace("@media (max-width: 640px) >> ", "@640 ")
        selector = selector.replace("@media (max-width: 968px) >> ", "@968 ")
        if selector not in selectors:
            selectors.append(selector)
    return "; ".join(selectors)


def write_markdown(records):
    current = None
    for record in records:
        if record["category"] != current:
            current = record["category"]
            sys.stdout.write(f"\n### {current}\n\n")
            sys.stdout.write("| Value | Count | Where |\n| --- | --- | --- |\n")
        value = record["value"].replace("|", "\\|")
        where = short_where(record["where"]).replace("|", "\\|")
        sys.stdout.write(f"| `{value}` | {record['count']} | {where} |\n")


def declarations(body: str):
    # Ignore nested braces; the stylesheet has none inside rule bodies.
    for chunk in body.split(";"):
        if ":" not in chunk:
            continue
        prop, value = chunk.split(":", 1)
        prop = prop.strip()
        if not prop or prop.startswith("@"):
            continue
        yield prop, normalize(value)


if __name__ == "__main__":
    main()
