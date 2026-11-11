"""Upstream CHECKER adapter: preserve each command's raw output and exit status."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def capture(argv):
    if not argv:
        raise ValueError('missing upstream command')
    root = Path(os.environ['TVP_UPSTREAM_RAW'])
    if not root.is_absolute() or str(root) != str(root.resolve(strict=True)):
        raise ValueError('canonical upstream capture directory required')
    units = root/'commands'
    if units.is_symlink() or not units.is_dir():
        raise ValueError('missing upstream command directory')
    cwd = os.getcwd()
    identity = hashlib.sha256(json.dumps([cwd, argv]).encode()).hexdigest()
    counter = 0
    while True:
        directory = units/(identity + '-' + str(counter))
        try:
            directory.mkdir()
            break
        except FileExistsError:
            counter += 1
    with (directory/'stdout').open('xb') as output, (directory/'stderr').open('xb') as errors:
        try:
            status = subprocess.run(argv, stdout=output, stderr=errors).returncode
        except OSError as error:
            errors.write((repr(error) + '\n').encode())
            status = 127
    (directory/'exit.json').write_text(json.dumps({'argv': argv, 'cwd': cwd, 'exit': status}) + '\n')
    with (directory/'stdout').open('rb') as output:
        shutil.copyfileobj(output, sys.stdout.buffer)
    with (directory/'stderr').open('rb') as errors:
        shutil.copyfileobj(errors, sys.stderr.buffer)
    sys.stdout.buffer.flush()
    sys.stderr.buffer.flush()
    return status if status >= 0 else 128 - status


if __name__ == '__main__':
    sys.exit(capture(sys.argv[1:]))
