"""Classify exact reproduced outcomes without rewriting upstream results."""
import collections
import json
from pathlib import Path
import re
import sys

raw_path, analysis_path, version, system, raw_root = sys.argv[1:]
raw = json.loads(Path(raw_path).read_text())
analysis = json.loads(Path(analysis_path).read_text())
assert analysis["version"] == version == "16.2.0"
assert analysis["system"] == system == "x86_64-linux"
suites = raw["suites"]
assert suites, "No upstream summaries"
tools = ["gcc", "g++", "libstdc++", "libgomp", "libatomic", "libitm"]
assert collections.Counter(Path(name).stem for name in suites) == collections.Counter(tools)
for tool in tools:
    found = [s for name, s in suites.items() if name.endswith("/" + tool + ".sum")]
    assert found and sum(s["counts"].get("PASS", 0) for s in found) > 0, tool
counts = collections.Counter()
unexpected = collections.Counter()
for suite in suites.values():
    counts.update(suite["counts"])
    unexpected.update(suite["unexpected"])
# Require complete raw summaries, not merely one passing case per tool.
root = Path(raw_root)
assert {str(p.relative_to(root)) for p in root.rglob("*.sum")} == set(suites)
footer_tags = {
    "expected passes": "PASS",
    "unexpected failures": "FAIL",
    "unexpected successes": "XPASS",
    "expected failures": "XFAIL",
    "unsupported tests": "UNSUPPORTED",
    "unresolved testcases": "UNRESOLVED",
    "untested testcases": "UNTESTED",
    "errors": "ERROR",
    "warning messages": "WARNING",
}
result_tags = "PASS|FAIL|XPASS|XFAIL|UNSUPPORTED|UNRESOLVED|UNTESTED|ERROR|WARNING"
for name, suite in suites.items():
    text = (root / name).read_text()
    tool = Path(name).stem
    headers = list(re.finditer(
        r"^[ \t]*=== " + re.escape(tool) + r" Summary ===[ \t]*$", text, re.M,
    ))
    assert len(headers) == 1, (name, "Missing or repeated completed summary")
    records = re.findall(r"^(" + result_tags + r"): (.*)$", text, re.M)
    observed = collections.Counter(tag for tag, _ in records)
    assert observed == suite["counts"], (name, "Raw records disagree with JSON")
    raw_unexpected = collections.Counter(
        tag + ": " + case for tag, case in records
        if tag in {"FAIL", "XPASS", "UNRESOLVED", "ERROR"}
    )
    assert raw_unexpected == collections.Counter(suite["unexpected"]), (
        name, "Raw unexpected outcomes disagree with JSON",
    )
    tail = text[headers[0].end():]
    assert not re.search(r"^(" + result_tags + r"): ", tail, re.M), (
        name, "Results follow summary",
    )
    footer = collections.Counter()
    for label, value in re.findall(r"^# of (.+?)[ \t]+([0-9]+)[ \t]*$", tail, re.M):
        assert label in footer_tags, (name, label)
        tag = footer_tags[label]
        assert tag not in footer, (name, "Repeated summary total", tag)
        footer[tag] = int(value)
    assert footer == observed, (name, "Completed summary totals disagree with raw records")
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
    "completedRawSummaryCount": len(suites),
    "classification": analysis["groups"],
    "interpretation": "Known reproduced outcomes remain FAIL/XPASS. Any added, changed, or disappeared unexpected outcome requires review.",
}, indent=2))
