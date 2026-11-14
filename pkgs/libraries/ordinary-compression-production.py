"""Production-only compression preparation; upstream frontends are a separate input.

Untouched procedures keep ordinary-compression-source.py's exact combined API.
This helper does not read, validate or rewrite the contents of test scripts.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import sys

family, shell, common_path = sys.argv[1:]
if family not in {"bzip2", "zlib", "xz", "zstd"} or not shell.startswith("/"):
    raise ValueError("explicit package and absolute shell required")
common = runpy.run_path(common_path)
root = Path.cwd()
files = common["source_files"](root)
text = common["text"]
changes = {}
required = {
    "bzip2": ["Makefile", "Makefile-libbz2_so", "bzlib.h"],
    "zlib": ["configure", "Makefile.in", "zlib.h"],
    "xz": ["configure", "build-aux/ltmain.sh"] + [
        "src/scripts/" + name + ".in" for name in ("xzdiff", "xzgrep", "xzmore", "xzless")],
    "zstd": ["Makefile", "lib/Makefile", "programs/Makefile"],
}[family]
for name in required:
    if root / name not in files:
        raise ValueError(("missing independent source target", name))
if family in {"zlib", "xz"}:
    path = root / "configure"
    data = text(path)
    if not re.match(rb"#![ \t]*/bin/sh\n", data):
        raise ValueError("expected original configure /bin/sh frontend")
    changes[path] = b"#!" + shell.encode() + b"\n" + data.split(b"\n", 1)[1]
if family == "xz":
    for name in required[2:]:
        if not text(root / name).startswith(b"#!@POSIX_SHELL@\n"):
            raise ValueError(("unsupported installed-script template", name))
    for path in files:
        relative = path.relative_to(root)
        if path == root / "build-aux/ltmain.sh":
            data = text(path)
            search = b" ".join(flag[2:].encode() for flag in os.environ.get("NIX_LDFLAGS", "").split()
                               if flag.startswith("-L"))
            data, count = re.subn(rb"eval (sys_lib_search_path=).*",
                                 lambda match: match[1] + b"'" + search + b"'", data)
            if count != 1:
                raise ValueError(("ltmain search anchor", path, count))
            changes[path] = re.sub(rb"eval sys_lib_.+search_path=.*", b"", data)
        if path == root / "configure":
            changes[path] = changes[path].replace(b"/usr/bin/file", b"file")
        if (relative.parts[0] == "build-aux" and relative.as_posix() != "build-aux/test-driver"
                and path.read_bytes().startswith(b"#!")):
            data = text(path)
            front = data.split(b"\n", 1)[0]
            if re.fullmatch(rb"#![ \t]*(?:/bin/(?:sh|bash)|/usr/bin/env (?:sh|bash))", front):
                changes[path] = b"#!" + shell.encode() + b"\n" + changes.get(path, data).split(b"\n", 1)[1]
            elif path.suffix in {".sh", ".test"}:
                raise ValueError(("unexpected production frontend", path, front))
common["stage"](changes)
print(json.dumps({"family": family, "scope": "production", "validatedFiles": len(files),
                  "adaptations": {str(path.relative_to(root)): hashlib.sha256(data).hexdigest()
                                  for path, data in changes.items()}}, sort_keys=True))
