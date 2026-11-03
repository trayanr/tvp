import os
import sys
sys.path.insert(0, sys.argv[3])
from common import files, invocation, preserving_times

root, config = invocation()
old = os.environ['TVP_ARTIFACT_ROOT'].encode()
new = str(root).encode()
for path in files(root, config['paths']):
    data = path.read_bytes()
    if b'\0' in data:
        raise ValueError(f'not text: {path}')
    preserving_times(path, lambda: path.write_bytes(data.replace(old, new)))
