"""Run upstream cases unchanged, skipping only unsupported kernel operations."""
import os
from pathlib import Path
import subprocess
import sys

CAPABILITIES = {
    "attr": {"attr.run": "xattrs", "restore.run": "xattrs"},
    "acl": {
        "cp.run": "acls",
        "misc.run": "acls",
        "setfacl-X.run": "acls",
        "sbits-restore.run": "set-id",
    },
}


def main():
    if len(sys.argv) < 5 or sys.argv[1] not in CAPABILITIES:
        raise SystemExit("usage: runner SUITE PROBE UPSTREAM-RUNNER TEST [arguments]")
    suite, probe, runner, *arguments = sys.argv[1:]
    case = Path(arguments[-1])
    capability = CAPABILITIES[suite].get(case.name) if case.parent.name == "test" else None
    if capability:
        status = subprocess.run([probe, capability]).returncode
        if status:
            return status if status > 0 else 1
    os.execv(runner, [runner, *arguments])


if __name__ == "__main__":
    sys.exit(main())
