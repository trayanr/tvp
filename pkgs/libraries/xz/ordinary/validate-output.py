"""Validate installed text before the relocator chooses text or binary routing.

Keep this finalization policy separate from the source preparation guard so an
output-only repair does not invalidate the compiled artifact.
"""
import os
from pathlib import Path
import runpy
import sys


def validate(name, tree_guard, text_guard):
    root = tree_guard('output', name)
    for directory, dirs, names in os.walk(root, followlinks=False):
        for name in names:
            path = Path(directory) / name
            relative = path.relative_to(root)
            if (path.suffix in {'.pc', '.la', '.h', '.m4', '.txt'}
                    or relative.parts[0] == 'nix-support'
                    or relative.parts[:2] in {
                        ('share', 'man'), ('share', 'doc'),
                        ('share', 'aclocal'), ('share', 'licenses')}):
                # The tree guard already confines aliases and rejects special
                # nodes. Validate a known text alias's contents as well as a
                # regular leaf, regardless of its target's filename.
                text_guard(path)
    return root


if __name__ == '__main__':
    guard = runpy.run_path(sys.argv[1])
    validate(sys.argv[2], guard['validate'], guard['text'])
