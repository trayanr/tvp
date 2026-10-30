"""Classify exact reproduced outcomes without rewriting upstream results."""
import collections
import json
from pathlib import Path
import sys

raw_path, analysis_path, version, system = sys.argv[1:]
raw = json.loads(Path(raw_path).read_text())
analysis = json.loads(Path(analysis_path).read_text())
assert analysis["version"] == version == "16.2.0"
assert analysis["system"] == system == "x86_64-linux"
suites = raw["suites"]
assert suites, "No upstream summaries"
for tool in ["gcc", "g++", "libstdc++", "libgomp", "libatomic", "libitm"]:
    found = [s for name, s in suites.items() if name.endswith("/" + tool + ".sum")]
    assert found and sum(s["counts"].get("PASS", 0) for s in found) > 0, tool
counts = collections.Counter()
unexpected = collections.Counter()
for suite in suites.values():
    counts.update(suite["counts"])
    unexpected.update(suite["unexpected"])
assert counts["ERROR"] == counts["UNRESOLVED"] == 0, "Unresolved harness/runtime outcomes"
classified = collections.Counter()
for group in analysis["groups"]:
    assert group["id"] and group["reason"] and group["reproduction"]
    assert all(line.startswith(("FAIL: ", "XPASS: ")) for line in group["observedUnexpected"])
    classified.update(group["observedUnexpected"])
assert unexpected == classified, json.dumps({
    "unclassified": list((unexpected - classified).elements()),
    "missingPreviouslyReproduced": list((classified - unexpected).elements()),
}, indent=2)
print(json.dumps({
    "schema": 1,
    "version": version,
    "system": system,
    "strictUpstreamConformance": not bool(unexpected),
    "rawCounts": dict(counts),
    "rawUnexpectedOutcomes": list(unexpected.elements()),
    "classification": analysis["groups"],
    "interpretation": "Known reproduced outcomes remain FAIL/XPASS. Any added, changed, or disappeared unexpected outcome requires review.",
}, indent=2))
