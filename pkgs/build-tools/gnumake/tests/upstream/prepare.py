"""Apply source-bound Make test-harness adaptations after checkpoint restore."""
from pathlib import Path
import os
import stat
import sys

profile = sys.argv[1]
shell = os.fsencode(sys.argv[2])
if not shell.startswith(b"/nix/store/") or any(c in shell for c in (b"'", b'"', b"\\", b"\0", b"\n")):
    raise ValueError("expected declared test-shell path")
root = Path.cwd()
if root.resolve(strict=True) != root or root.is_symlink():
    raise ValueError("expected private canonical test root")
sh_name = (b"$sh_name = '/bin/sh';", b"$sh_name = '" + shell + b"';")
diagnostic = (b"$_ = `/bin/sh -c 'bad-command 2>&1'`;", b"$_ = `" + shell + b" -c 'bad-command 2>&1'`;")
profiles = {
    "4.3": {"tests/run_make_tests.pl": [sh_name]},
    "4.4": {"tests/run_make_tests.pl": [sh_name, diagnostic],
            # Keep every synchronization assertion; retain the established 60s limit.
            "tests/thelp.pl": [(b"my $timeout = 10;", b"my $timeout = 60;")]},
    "4.4.1": {"tests/run_make_tests.pl": [diagnostic]},
}
if profile not in profiles:
    raise ValueError("unsupported source-bound GNU Make test profile")
changes = []
for spelling, replacements in profiles[profile].items():
    path = root / spelling
    for parent in [path, *path.parents]:
        if parent.is_symlink():
            raise ValueError(f"source alias: {parent}")
        if parent == root:
            break
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        raise ValueError(f"expected singly linked harness source: {spelling}")
    data = path.read_bytes()
    for old, new in replacements:
        if data.count(old) != 1:
            raise ValueError(("unexpected Make test source", profile, spelling, old))
        data = data.replace(old, new)
    changes.append((path, info, data))
# Validate the complete profile before the first write.
for path, info, data in changes:
    path.write_bytes(data)
    os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
