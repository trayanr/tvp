"""Directory audit controls; no package compilation or external subprocesses."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

helper, common = map(Path, sys.argv[1:3])
cases = []


def case(name, setup, succeeds, selectors=None):
    with tempfile.TemporaryDirectory(prefix="tvp-symlink-tree-") as temporary:
        root = Path(temporary) / "out"
        (root / "bin/nested").mkdir(parents=True)
        (root / "lib").mkdir()
        (root / "lib/target").write_text("unchanged")
        setup(root)
        reference = None
        if succeeds is None:
            try:
                os.stat(root / "bin/tool")
                reference = {"resolves": True, "errno": None}
            except OSError as error:
                reference = {"resolves": False, "errno": error.errno}
            succeeds = reference["resolves"]
        args = [sys.executable, "-B", str(helper), str(root),
                json.dumps({"paths": selectors if selectors is not None else ["bin"]}), str(common)]
        result = subprocess.run(args, capture_output=True, text=True, timeout=5)
        assert (result.returncode == 0) == succeeds, (name, result.returncode, result.stderr)
        assert (root / "lib/target").read_text() == "unchanged"
        cases.append({"name": name, "expected": "PASS" if succeeds else "REJECT",
                      "exit": result.returncode, "linuxReference": reference})


def links(*entries):
    def setup(root):
        for name, target in entries:
            (root / name).symlink_to(target)
    return setup


case("plain-sdk-bin-directory", lambda _: None, True)
case("nested-relative-file", links(("bin/nested/tool", "../../lib/target")), True)
case("relative-directory-not-followed", links(("bin/library", "../lib")), True)
case("relative-chain", links(("bin/tool", "../lib/link"), ("lib/link", "target")), True)
case("in-output-parent-component", links(("bin/tool", "nested/../../lib/target")), True)
case("absolute-target", links(("bin/tool", "/etc/passwd")), False)
case("escape-target", links(("bin/tool", "../../outside")), False)
case("dangling-target", links(("bin/tool", "missing")), False)
case("self-cycle", links(("bin/tool", "tool")), False)
case("two-link-cycle", links(("bin/a", "b"), ("bin/b", "a")), False)
case("hidden-absolute-chain", lambda r: links(("bin/tool", "../lib/link"),
     ("lib/link", str(r / "lib/target")))(r), False)
case("hidden-escaping-chain", links(("bin/tool", "../lib/link"),
     ("lib/link", "../../outside")), False)
case("regular-file-selector", lambda _: None, False, ["lib/target"])
case("symlink-selector-parent", links(("alias", "lib")), False, ["alias/target"])
case("symlink-directory-selector", links(("alias", "bin")), False, ["alias"])
case("empty-selectors", lambda _: None, False, [])
case("unsupported-file", lambda r: os.mkfifo(r / "bin/pipe"), False)
# Compare raw in-output path spelling with the kernel instead of normalizing
# it in the test. Absolute/escaping policy cases above are intentionally stricter.
def raw_target(target):
    def setup(root):
        (root / "lib/directory").mkdir()
        (root / "lib/directory/file").write_text("directory child")
        for name, value in [
            ("file-link", "target"), ("dir-link", "directory"),
            ("chained-file", "file-link"), ("chained-dir", "dir-link"),
            ("file-slash", "target/"), ("file-dot", "target/."),
            ("dir-slash", "directory/"), ("dir-dot", "directory/."),
        ]:
            (root / "lib" / name).symlink_to(value)
        (root / "bin/tool").symlink_to(target)
    return setup


for target in [
    "target", "directory", "file-link", "dir-link", "chained-file",
    "chained-dir", "file-slash", "file-dot", "dir-slash", "dir-dot",
]:
    for suffix in ["", "/", "/.", "/./", "//", "//.", "/..", "/../target"]:
        case(f"linux-resolution:{target}{suffix}",
             raw_target(f"../lib/{target}{suffix}"), None)

print(json.dumps({"passed": len(cases), "cases": cases}, indent=2))
