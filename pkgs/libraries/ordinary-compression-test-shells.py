"""Upstream-only source frontends; never an input to the compilation artifact."""
import hashlib
import json
from pathlib import Path
import re
import runpy
import sys

family, shell, common_path = sys.argv[1:]
if family not in {"xz", "zstd"} or not shell.startswith("/"):
    raise ValueError("explicit upstream package and absolute shell required")
common = runpy.run_path(common_path)
root = Path.cwd()
files = common["source_files"](root)
text = common["text"]
changes = {}
if family == "zstd":
    runner = root / "tests/cli-tests/run.py"
    if runner not in files or not text(runner).startswith(b"#!/usr/bin/env python3\n"):
        raise ValueError("unexpected upstream Python frontend")
for path in files:
    relative = path.relative_to(root)
    selected = (relative.parts[0] == "tests" or relative.as_posix() == "build-aux/test-driver") if family == "xz" else path.is_relative_to(root / "tests/cli-tests") and path.suffix == ".sh"
    if not selected:
        continue
    data = path.read_bytes()
    if not data.startswith(b"#!"):
        if family == "zstd" and path.parent.name != "common":
            raise ValueError(("missing upstream shell frontend", path))
        continue
    data = text(path)
    front = data.split(b"\n", 1)[0]
    if re.fullmatch(rb"#![ \t]*" + re.escape(shell.encode()), front):
        # Configure may generate a check script with this already-selected shell.
        continue
    if re.fullmatch(rb"#![ \t]*(?:/bin/(?:sh|bash)|/usr/bin/env (?:sh|bash))", front):
        changes[path] = b"#!" + shell.encode() + b"\n" + data.split(b"\n", 1)[1]
    elif path.suffix in {".sh", ".test"}:
        raise ValueError(("unexpected upstream shell frontend", path, front))
common["stage"](changes)
print(json.dumps({"family": family, "scope": "upstream", "validatedFiles": len(files),
                  "adaptations": {str(path.relative_to(root)): hashlib.sha256(data).hexdigest()
                                  for path, data in changes.items()}}, sort_keys=True))
