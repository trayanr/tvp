"""Inspect actual loader resolution and reject any mismatched provider path."""
import importlib
import os
from pathlib import Path
import re
import subprocess
import sys
provider, pattern, *modules = sys.argv[1:]
for module in modules:
    path = importlib.import_module(module).__file__
    # Invoke the declared base loader, rather than a foreign ldd shell script.
    interpreter = subprocess.check_output(['readelf', '-l', sys.executable], text=True)
    loader = re.search(r'Requesting program interpreter: (.+?)\]', interpreter)[1]
    loaded = subprocess.check_output([loader, '--list', path], text=True)
    selected = [line.split('=>', 1)[1].strip().split()[0] for line in loaded.splitlines()
                if re.search(pattern, line) and '=>' in line]
    assert selected, (module, pattern, loaded)
    assert all(str(Path(p).parent) == provider for p in selected), (module, provider, selected)
    print(loaded, file=sys.stderr)
print('linked')
