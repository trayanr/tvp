"""Save an installed producer's compiled source tree without test policy."""
import json
import os
from pathlib import Path
import shutil
import stat
import sys


def absolute(value):
    path = Path(value)
    if not path.is_absolute() or any(p in ("", ".", "..") for p in value.split("/")[1:]):
        raise ValueError("expected canonical absolute build path")
    return path


def validate_tree(root):
    for parent, dirs, files in os.walk(root, followlinks=False):
        for path in [Path(parent)] + [Path(parent) / name for name in dirs + files]:
            mode = path.lstat().st_mode
            if not (stat.S_ISDIR(mode) or stat.S_ISREG(mode) or stat.S_ISLNK(mode)):
                raise ValueError(f"unsupported build-tree object: {path}")


def save(workspace, destination):
    source = workspace / "source"
    if source.is_symlink() or not source.is_dir() or destination.exists():
        raise ValueError("invalid checkpoint source or existing destination")
    validate_tree(source)
    destination.mkdir(parents=True)
    timestamps = {}
    for parent, dirs, files in os.walk(source, followlinks=False):
        for path in [Path(parent)] + [Path(parent) / name for name in dirs + files]:
            timestamps[str(path.relative_to(source))] = path.lstat().st_mtime_ns
    shutil.copytree(source, destination / "source", symlinks=True)
    (destination / "layout.json").write_text(json.dumps({
        "schema": 1,
        "timestamps": timestamps,
        "workspace": str(workspace),
        "sourceDateEpoch": (workspace / "source-date-epoch").read_text().strip(),
    }) + "\n")



if __name__ == "__main__":
    save(absolute(sys.argv[1]), absolute(sys.argv[2]))
