#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
exec python3 - "$root/lint-baseline.json" "$@" <<'PY'
import json
import os
import sys

PACKAGE_ORDER = ("root", "shared", "client")
baseline_path = sys.argv[1]
args = sys.argv[2:]
update = False
pairs = []
for arg in args:
    if arg == "--update":
        update = True
        continue
    if "=" not in arg:
        sys.stderr.write(
            "usage: scripts/lint-ratchet.sh [--update] root=glinter.json [shared=glinter.json] [client=glinter.json]\n"
        )
        sys.exit(2)
    name, path = arg.split("=", 1)
    if name not in PACKAGE_ORDER:
        sys.stderr.write("unknown package %s\n" % name)
        sys.exit(2)
    pairs.append((name, path))

if not pairs:
    sys.stderr.write(
        "usage: scripts/lint-ratchet.sh [--update] root=glinter.json [shared=glinter.json] [client=glinter.json]\n"
    )
    sys.exit(2)

seen = []
for name, _path in pairs:
    if name in seen:
        sys.stderr.write("package %s was given twice\n" % name)
        sys.exit(2)
    seen.append(name)


def fail(message):
    sys.stderr.write(message + "\n")
    sys.exit(1)


def extract_report(text):
    decoder = json.JSONDecoder()
    chosen = None
    index = 0
    while True:
        start = text.find("{", index)
        if start < 0:
            break
        try:
            obj, end = decoder.raw_decode(text, start)
        except json.JSONDecodeError:
            index = start + 1
            continue
        index = end
        if not isinstance(obj, dict):
            continue
        summary = obj.get("summary")
        if isinstance(summary, dict) and "total" in summary:
            chosen = obj
    if chosen is None:
        fail("glinter JSON has no summary")
    results = chosen.get("results")
    if not isinstance(results, list):
        fail("glinter JSON summary has no results")
    counts = {}
    for item in results:
        if not isinstance(item, dict) or not isinstance(item.get("rule"), str):
            fail("glinter JSON result has no rule")
        rule = item["rule"]
        counts[rule] = counts.get(rule, 0) + 1
    total = chosen["summary"]["total"]
    if not isinstance(total, int) or isinstance(total, bool):
        fail("glinter JSON summary total is not an integer")
    if total != sum(counts.values()):
        fail(
            "glinter JSON summary total is %s, results sum to %s"
            % (total, sum(counts.values()))
        )
    return counts, total


def read_report(path):
    try:
        text = open(path, encoding="utf-8").read()
    except OSError as error:
        fail("cannot read %s (%s)" % (path, error.strerror))
    return extract_report(text)


def as_counts(entry, label):
    if not isinstance(entry, dict):
        fail("lint-baseline.json %s is not an object" % label)
    rules = entry.get("rules")
    total = entry.get("total")
    if not isinstance(rules, dict) or not isinstance(total, int) or isinstance(total, bool):
        fail("lint-baseline.json %s needs an integer total and a rules object" % label)
    cleaned = {}
    for rule, count in rules.items():
        if not isinstance(rule, str) or not isinstance(count, int) or isinstance(count, bool) or count < 0:
            fail("lint-baseline.json %s has a bad rule count" % label)
        if count != 0:
            cleaned[rule] = count
    if total != sum(cleaned.values()):
        fail(
            "lint-baseline.json %s total is %s, rules sum to %s"
            % (label, total, sum(cleaned.values()))
        )
    return cleaned, total


def load_baseline():
    if not os.path.exists(baseline_path):
        return None
    try:
        data = json.loads(open(baseline_path, encoding="utf-8").read())
    except (OSError, json.JSONDecodeError) as error:
        fail("cannot parse lint-baseline.json (%s)" % error)
    if not isinstance(data, dict):
        fail("lint-baseline.json is not an object")
    loaded = {}
    for name, entry in data.items():
        if name not in PACKAGE_ORDER:
            fail("lint-baseline.json has unknown package %s" % name)
        loaded[name] = as_counts(entry, name)
    return loaded


def canonical(data):
    ordered = {}
    for name in PACKAGE_ORDER:
        if name not in data:
            continue
        rules, total = data[name]
        ordered[name] = {
            "total": total,
            "rules": {rule: rules[rule] for rule in sorted(rules)},
        }
    return json.dumps(ordered, indent=2) + "\n"


def write_baseline(data):
    text = canonical(data)
    temporary = baseline_path + ".tmp"
    with open(temporary, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(temporary, baseline_path)


def rule_delta(before, after):
    rose = []
    fell = []
    for rule in sorted(set(before) | set(after)):
        old = before.get(rule, 0)
        new = after.get(rule, 0)
        if new > old:
            rose.append((rule, old, new))
        elif new < old:
            fell.append((rule, old, new))
    return rose, fell


actual = {}
for name, path in pairs:
    actual[name] = read_report(path)

existing = load_baseline()
if existing is None:
    if not update:
        fail(
            "lint-baseline.json is missing. Run scripts/check.sh --update-lint-baseline to create it."
        )
    write_baseline(actual)
    sys.stdout.write("wrote lint-baseline.json\n")
    for name, _path in pairs:
        rules, total = actual[name]
        sys.stdout.write("  %s total %s\n" % (name, total))
        for rule in sorted(rules):
            sys.stdout.write("  %s %s %s\n" % (name, rule, rules[rule]))
    sys.exit(0)

rose_lines = []
fell_lines = []
merged = dict(existing)
for name, _path in pairs:
    before_rules, before_total = existing.get(name, ({}, 0))
    after_rules, after_total = actual[name]
    rose, fell = rule_delta(before_rules, after_rules)
    for rule, old, new in rose:
        rose_lines.append("%s %s rose from %s to %s" % (name, rule, old, new))
    if after_total > before_total:
        rose_lines.append("%s total rose from %s to %s" % (name, before_total, after_total))
    for rule, old, new in fell:
        fell_lines.append("%s %s fell from %s to %s" % (name, rule, old, new))
    if after_total < before_total:
        fell_lines.append("%s total fell from %s to %s" % (name, before_total, after_total))
    merged[name] = (after_rules, after_total)

if rose_lines:
    sys.stderr.write("lint baseline rose\n")
    for line in rose_lines:
        sys.stderr.write("  %s\n" % line)
    if update:
        sys.stderr.write("scripts/check.sh --update-lint-baseline does not raise counts\n")
    sys.exit(1)

if update:
    current = canonical(existing)
    updated = canonical(merged)
    if current == updated:
        sys.stdout.write("lint baseline unchanged\n")
    else:
        write_baseline(merged)
        sys.stdout.write("lint baseline lowered\n")
        for line in fell_lines:
            sys.stdout.write("  %s\n" % line)
    sys.exit(0)

sys.stdout.write("lint baseline ok\n")
for name, _path in pairs:
    _rules, total = actual[name]
    sys.stdout.write("  %s total %s\n" % (name, total))
if fell_lines:
    sys.stdout.write("counts are under lint-baseline.json\n")
    for line in fell_lines:
        sys.stdout.write("  %s\n" % line)
    sys.stdout.write("Run scripts/check.sh --update-lint-baseline to record the lower counts.\n")
PY
