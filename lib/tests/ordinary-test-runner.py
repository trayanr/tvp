"""Bounded independent capability preflight for selected ordinary upstream cases."""
from pathlib import Path
import subprocess
import sys

suite, probe, runner, *arguments = sys.argv[1:]
case = Path(arguments[-1])
capabilities = {
    'acl23': {'test/cp.test': 'acls', 'test/misc.test': 'acls',
              'test/setfacl-X.test': 'acls', 'test/sbits-restore.test': 'set-id'},
    'coreutils': {'tests/install/install-C.sh': 'set-id'},
}
assert suite in capabilities
capability = next((value for name, value in capabilities[suite].items()
                   if case.as_posix().endswith('/' + name) or case.as_posix() == name), None)
if capability:
    status = subprocess.run([probe, capability]).returncode
    if status:
        sys.exit(status if status > 0 else 1)
status = subprocess.run([runner, *arguments]).returncode
if capability and status == 77:
    sys.exit('upstream fixture skipped after successful independent preflight')
sys.exit(status if status >= 0 else 1)
