"""Source token edits must reject unsafe targets before changing either file."""
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile


helper = Path(sys.argv[1]).resolve()
targets = [
    ("src/java.base/unix/native/libjava/childproc.c", "@TVP_SHELL@", "selected-shell"),
    ("src/java.desktop/unix/native/common/awt/fontpath.c", "@TVP_FONTCONFIG@", "selected-font"),
]


def snapshot(root):
    result = {}
    for directory, _, names in os.walk(root, followlinks=False):
        for name in names:
            path = Path(directory) / name
            if stat.S_ISREG(path.lstat().st_mode):
                result[str(path.relative_to(root))] = path.read_bytes()
    return result


def case(kind, target_index):
    with tempfile.TemporaryDirectory(prefix="jdk-source-boundary-") as directory:
        root = Path(directory)
        source = root / "source"
        for filename, token, _ in targets:
            path = source / filename
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f"before {token} after\n")
        filename, token, _ = targets[target_index]
        path = source / filename
        outside = root / "outside"
        outside.mkdir()
        if kind == "leaf-symlink":
            destination = outside / "target"
            destination.write_text(path.read_text())
            path.unlink()
            path.symlink_to(destination)
        elif kind == "parent-symlink":
            path.rename(outside / path.name)
            path.parent.rmdir()
            path.parent.symlink_to(outside, target_is_directory=True)
        elif kind == "missing-token":
            path.write_text("no patch token\n")
        elif kind == "duplicate-token":
            path.write_text(f"{token} {token}\n")
        elif kind in ("missing-file", "directory", "fifo"):
            path.unlink()
            if kind == "directory":
                path.mkdir()
            elif kind == "fifo":
                os.mkfifo(path)
        before = snapshot(root)
        process = subprocess.run(
            [sys.executable, "-B", str(helper), targets[0][2], targets[1][2]],
            cwd=source,
            capture_output=True,
            text=True,
            timeout=5,
        )
        if kind == "regular":
            assert process.returncode == 0, process.stderr
            for filename, token, value in targets:
                assert (source / filename).read_text() == f"before {value} after\n"
        else:
            assert process.returncode != 0, (kind, target_index)
            assert snapshot(root) == before, (kind, target_index, "unexpected mutation")


case("regular", 0)
kinds = [
    "leaf-symlink", "parent-symlink", "missing-token", "duplicate-token",
    "missing-file", "directory", "fifo",
]
for kind in kinds:
    for index in range(len(targets)):
        case(kind, index)
print(json.dumps({"sourcePathCases": 1 + len(kinds) * len(targets), "passed": True}), file=sys.stderr)
