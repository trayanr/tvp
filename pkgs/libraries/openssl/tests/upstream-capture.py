"""Raw subprocess capture: unsuccessful workloads are valid R, never U passes."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
root.mkdir(parents=True, exist_ok=False)
with (root / 'output').open('wb') as out:
    result = subprocess.run(sys.argv[2:], stdout=out, stderr=subprocess.STDOUT)
status = result.returncode if result.returncode >= 0 else 128 - result.returncode
(root / 'exit').write_text(str(status) + '\n')
data = (root / 'output').read_bytes()
(root / 'capture.json').write_text(json.dumps({
    'schema': 1, 'status': status, 'bytes': len(data),
    'sha256': hashlib.sha256(data).hexdigest()}, sort_keys=True) + '\n')
sys.stdout.buffer.write(data)
