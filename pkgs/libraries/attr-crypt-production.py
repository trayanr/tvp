"""Production source frontends only; test policy is an independent U input."""
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import sys

family, shell, perl, common_path = sys.argv[1:]
if family not in {"attr", "acl", "libxcrypt"} or not shell.startswith("/"):
    raise ValueError("explicit family and absolute shell required")
if family == "libxcrypt" and not perl.startswith("/"):
    raise ValueError("libxcrypt's production Perl generator is required")
common = runpy.run_path(common_path)
root = Path.cwd()
files = common["source_files"](root)
text = common["text"]
changes = {}
configure = root / "configure"
if configure not in files:
    raise ValueError("independent configure required")
data = text(configure)
if not re.match(rb"#![ \t]*/bin/sh\n", data):
    raise ValueError("unexpected configure frontend")
changes[configure] = b"#!" + shell.encode() + b"\n" + data.split(b"\n", 1)[1]
changes[configure] = changes[configure].replace(b"/usr/bin/file", b"file")
# check-perlcritic-config and skip-if-exec-format-error are development/check
# programs, not production generators. test-driver is always prepared in U.
test_only = {"test-driver", "check-perlcritic-config", "skip-if-exec-format-error"}
for path in root.rglob("*"):
    rel = path.relative_to(root)
    if path.is_symlink() and rel.parts[0] == "build-aux" and path.name not in test_only:
        raise ValueError(("aliased production frontend", path))
for path in files:
    rel = path.relative_to(root)
    if rel.parts[0] != "build-aux" or path.name in test_only:
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
    elif pl and family == "libxcrypt":
        changes[path] = b"#!" + perl.encode() + (b" " + pl[1] if pl[1] else b"") + b"\n" + body
    else:
        raise ValueError(("unexpected production frontend", path, front))
    if path.name == "ltmain.sh":
        search = b" ".join(flag[2:].encode() for flag in os.environ.get("NIX_LDFLAGS", "").split() if flag.startswith("-L"))
        changed, count = re.subn(rb"eval (sys_lib_search_path=).*", lambda m: m[1] + b"'" + search + b"'", changes[path])
        if count != 1:
            raise ValueError(("ltmain search anchor", path, count))
        changes[path] = re.sub(rb"eval sys_lib_.+search_path=.*", b"", changed)
common["stage"](changes)
print(json.dumps({"family": family, "scope": "production", "adaptations": {
    str(p.relative_to(root)): hashlib.sha256(data).hexdigest() for p,data in changes.items()}}, sort_keys=True))
