"""Prepare only upstream frontends after restoring the compiled checkpoint."""
import hashlib
import json
from pathlib import Path
import re
import runpy
import os
import stat
import sys

family, shell, perl, common_path = sys.argv[1:]
if family not in {"attr", "acl"} or not shell.startswith("/") or not perl.startswith("/"):
    raise ValueError("explicit family and absolute shell/Perl required")
common = runpy.run_path(common_path)
root = Path.cwd()
# A configured tree has generated include aliases and library build outputs.
# Validate the selected upstream subtree, not unrelated production directories.
files = []
tests = root / "test"
if os.path.lexists(tests):
    files.extend(common["source_files"](tests))
for name in ["test-driver", "check-perlcritic-config", "skip-if-exec-format-error"]:
    path = root / "build-aux" / name
    if not os.path.lexists(path):
        continue
    for parent in [root / "build-aux", root, *root.parents]:
        if not stat.S_ISDIR(parent.lstat().st_mode):
            raise ValueError(("aliased upstream parent", parent))
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        raise ValueError(("aliased/shared upstream frontend", path))
    files.append(path)
text = common["text"]
changes = {}
for path in files:
    rel = path.relative_to(root)
    selected = rel.parts[0] == "test" or (rel.parts[0] == "build-aux" and path.name in {
        "test-driver", "check-perlcritic-config", "skip-if-exec-format-error"})
    if not selected:
        continue
    data = path.read_bytes()
    if not data.startswith(b"#!"):
        continue
    data = text(path)
    front, body = data.split(b"\n", 1)
    sh = re.fullmatch(rb"#![ \t]*(?:/(?:usr/)?bin/(?:sh|bash)|/usr/bin/env (?:sh|bash))(?: (-e|-))?", front)
    pl = re.fullmatch(rb"#![ \t]*(?:/usr/bin/perl|/usr/bin/env perl)(?: (-w(?: -U)?))?", front)
    if sh:
        changes[path] = b"#!" + shell.encode() + (b" " + sh[1] if sh[1] else b"") + b"\n" + body
    elif pl:
        changes[path] = b"#!" + perl.encode() + (b" " + pl[1] if pl[1] else b"") + b"\n" + body
    elif front not in {b"#!"+shell.encode(), b"#!"+perl.encode()}:
        raise ValueError(("unexpected upstream frontend", path, front))
common["stage"](changes)
print(json.dumps({"family": family, "scope": "upstream", "adaptations": {
    str(p.relative_to(root)): hashlib.sha256(data).hexdigest() for p,data in changes.items()}}, sort_keys=True))
