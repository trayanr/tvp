"""Execute upstream unchanged; retain immutable raw output and exit separately.

This artifact is evidence, not qualification. A final-stage classifier must accept
it before a canonical package can be produced. Never translate failure into PASS.
"""
import json
import os
from pathlib import Path
import subprocess
import sys


def capture(destination, argv):
    destination = Path(destination)
    destination.mkdir()  # no overwrite/retry in place
    (destination/'commands').mkdir()
    environment = dict(os.environ, TVP_UPSTREAM_RAW=str(destination.resolve(strict=True)))
    with (destination/'stdout').open('xb') as out:
        status = subprocess.run(argv, stdout=out, stderr=subprocess.STDOUT, env=environment).returncode
    (destination/'exit.json').write_text(json.dumps({'argv': argv, 'exit': status})+'\n')
    # Relevant operational logs remain byte-for-byte evidence, never final payload.
    for name in ('runsuite.log', 'runtest.log', 'runxmlconf.log', 'test-suite.log'):
        path = Path(name)
        if path.exists():
            if path.is_symlink() or not path.is_file():
                raise ValueError(('unexpected upstream log node', name))
            (destination/name).write_bytes(path.read_bytes())


if __name__ == '__main__':
    capture(sys.argv[1], sys.argv[2:])
