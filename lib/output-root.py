"""Run one existing output operation with its matching artifact prefix.

Only nondefault output helpers use this adapter. The runner's readonly Bash
bindings are untouched; the Python operation sees the selected artifact only.
"""
import os
from pathlib import Path
import runpy
import sys


def main():
    artifact, program = sys.argv[1:3]
    if artifact:
        if not artifact.startswith('/nix/store/') or '\0' in artifact:
            raise ValueError('expected selected store artifact prefix')
        os.environ['TVP_ARTIFACT_ROOT'] = artifact
    else:
        os.environ.pop('TVP_ARTIFACT_ROOT', None)
    sys.argv = sys.argv[2:]
    sys.path.insert(0, str(Path(program).parent))
    runpy.run_path(program, run_name='__main__')


if __name__ == '__main__':
    main()
