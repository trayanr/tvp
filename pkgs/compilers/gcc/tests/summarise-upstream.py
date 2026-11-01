"""Retain all DejaGNU outcomes; never turn a make exit into a test count."""
import collections
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
suites = {}
for path in sorted(root.rglob("*.sum")):
    counts = collections.Counter()
    unexpected = []
    for line in path.read_text(errors="replace").splitlines():
        tag, sep, name = line.partition(": ")
        if sep and tag in {"PASS", "FAIL", "XPASS", "XFAIL", "UNSUPPORTED", "UNRESOLVED", "UNTESTED", "ERROR", "WARNING"}:
            counts[tag] += 1
            if tag in {"FAIL", "XPASS", "UNRESOLVED", "ERROR"}:
                unexpected.append(line)
    suites[str(path.relative_to(root))] = {"counts": dict(counts), "unexpected": unexpected}
(root / "upstream.json").write_text(json.dumps({"schema": 1, "suites": suites}, indent=2) + "\n")
print(json.dumps(suites, indent=2))
