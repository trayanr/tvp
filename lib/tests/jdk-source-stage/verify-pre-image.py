import os
import subprocess
import sys
value = subprocess.check_output([os.environ["JDK_CONTROL_PATCHELF"], "--print-rpath", sys.argv[1]], text=True).strip()
assert sys.argv[2] in value.split(":"), value
assert "/unused" not in value, value
