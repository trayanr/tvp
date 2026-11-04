"""Keep the native sandbox's existing confstr(_CS_PATH) defect visible and bounded."""
from pathlib import Path
import sys

status = int(sys.argv[1])
log = Path("upstream.log").read_text()
failures = sorted(Path("tests/work").rglob("*.diff*"))
# GNU Make searches libc's /bin:/usr/bin when PATH is absent. These are not
# populated in a Nix sandbox. Do not add runtime tools or change this feature.
expected = Path("tests/work/misc/general4.diff.9")
assert status != 0 and failures == [expected], (status, failures)
assert Path("tests/work/misc/general4.base.9").read_text() == "hi\n"
assert Path("tests/work/misc/general4.log.9").read_text() == (
    "make: echo: No such file or directory\n"
    "make: *** [work/misc/general4.mk.9:2: a] Error 127\n"
)
assert "1 Test in 1 Category Failed" in log
print("KNOWN UPSTREAM FAIL: misc/general4 case 9: libc default PATH is absent in the sandbox; all other executed cases passed.")
