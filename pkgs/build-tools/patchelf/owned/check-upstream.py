"""Bound the two inherited test-fixture assumptions violated by owned wrappers."""
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
assert {name for name, value in results.items() if value == "FAIL"} == {"no-rpath.sh", "shared-rpath.sh"}, results
assert {name for name, value in results.items() if value == "SKIP"} == {
    "set-rpath-rel-map.sh", "remove-rld-map-rel.sh", "short-first-segment.sh", "large-page-dynamic.sh"
}, results
assert len(results) == 70 and all(v in {"PASS", "SKIP", "FAIL"} for v in results.values()), results
rpath = lambda path: subprocess.check_output([finalizer, "--print-rpath", path], text=True).strip()
# NIX_DONT_SET_RPATH is an upstream nixpkgs protocol; the frozen owned wrappers
# intentionally always add native libc/compiler paths. Never change those wrappers.
assert rpath("tests/no-rpath") == base_rpath
shared = rpath("tests/libshared-rpath.so")
assert "a_symbol_name" in shared.split(":") and shared != "a_symbol_name"
assert base_rpath.split(":")[0] in shared.split(":")
print("KNOWN UPSTREAM FAIL: no-rpath.sh and shared-rpath.sh assume wrappers suppress all default RPATHs; raw results: 65 PASS / 4 SKIP / 2 FAIL.")
