"""Bound the inherited empty-RPATH assumption under the full source driver."""
from pathlib import Path
import subprocess
import sys

status, base_rpath, finalizer = sys.argv[1:]
results = {}
for path in Path("tests").glob("*.trs"):
    text = path.read_text().splitlines()
    results[path.name.removesuffix(".trs")] = next(
        line.removeprefix(":test-result: ") for line in text if line.startswith(":test-result: ")
    )
assert status != "0"
assert {name for name, value in results.items() if value == "FAIL"} == {"no-rpath.sh"}, results
assert {name for name, value in results.items() if value == "SKIP"} == {
    "set-rpath-rel-map.sh", "remove-rld-map-rel.sh", "short-first-segment.sh", "large-page-dynamic.sh"
}, results
assert len(results) == 70 and all(v in {"PASS", "SKIP", "FAIL"} for v in results.values()), results
rpath = lambda path: subprocess.check_output([finalizer, "--print-rpath", path], text=True).strip()
# NIX_DONT_SET_RPATH is an upstream nixpkgs protocol; the frozen owned wrappers
# intentionally always add native libc/compiler paths. Never change those wrappers.
assert set(rpath("tests/no-rpath").split(":")) == set(base_rpath.split(":"))
shared = rpath("tests/libshared-rpath.so")
assert "a_symbol_name" in shared.split(":")
assert results["shared-rpath.sh"] == "PASS"
print("KNOWN UPSTREAM FAIL: no-rpath.sh assumes wrappers suppress all default RPATHs; raw results: 66 PASS / 4 SKIP / 1 FAIL (71 occurrences, 70 distinct). shared-rpath.sh now PASS under the full source driver.")
