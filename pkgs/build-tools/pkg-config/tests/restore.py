"""Restore pkg-config's compiled tree in a private upstream-test workspace."""
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


def writable(root):
    for parent, dirs, files in os.walk(root, followlinks=False):
        for path in [Path(parent)] + [Path(parent) / name for name in files]:
            if not path.is_symlink():
                path.chmod(path.stat().st_mode | stat.S_IWUSR)


def restore(checkpoint, workspace):
    layout = json.loads((checkpoint / "layout.json").read_text())
    if layout.get("schema") != 1:
        raise ValueError("unsupported checkpoint schema")
    original = absolute(layout["workspace"])
    # The destination must be a Nix build directory, never an arbitrary path
    # supplied by archive content. It is private to this sandbox invocation.
    spelling = str(original)
    if not (spelling == "/build" or spelling.startswith("/build/") or spelling.startswith("/nix/var/nix/builds/")
            or spelling.startswith("/tmp/nix-build-")):
        raise ValueError("checkpoint workspace is outside Nix build directories")
    source = checkpoint / "source"
    if source.is_symlink() or not source.is_dir():
        raise ValueError("invalid checkpoint tree")
    validate_tree(source)
    target = original / "source"
    # Resolve existing parents before any mkdir/copy operation.
    if original.resolve() != original:
        raise ValueError("checkpoint workspace resolves outside its spelling")
    if target.exists() or target.is_symlink():
        raise ValueError("checkpoint destination already exists")
    original.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, target, symlinks=True)
    writable(target)
    # Store registration normalizes mtimes; restore the build-time values so
    # upstream checks reuse the compiled library and generators.
    timestamps = layout["timestamps"]
    for parent, dirs, files in os.walk(target, followlinks=False):
        for path in [Path(parent)] + [Path(parent) / name for name in dirs + files]:
            stamp = timestamps[str(path.relative_to(target))]
            os.utime(path, ns=(stamp, stamp), follow_symlinks=False)
    (workspace / "tree-path").write_text(str(target) + "\n")
    (workspace / "source-date-epoch").write_text(layout["sourceDateEpoch"] + "\n")


if __name__ == "__main__":
    restore(absolute(sys.argv[1]), absolute(sys.argv[2]))
