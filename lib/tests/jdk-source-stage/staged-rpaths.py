"""Real, tiny native ELF fixtures for the narrow staged-root adapter."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

adapter, common, selector, readelf, patchelf, failing, installed, loader = sys.argv[1:]


def run(*args, **kwargs):
    return subprocess.run(list(map(str, args)), check=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, **kwargs)


with tempfile.TemporaryDirectory() as temporary:
    workspace = Path(temporary)
    stage = workspace / "source/build/fixture"
    root = stage / "jdk"
    root.mkdir(parents=True)
    source = workspace / "control.c"
    source.write_text('int main(void) { return 0; }\n')
    compiler = os.environ["CC"]
    run(compiler, source, "-Wl,-rpath,/unused", "-o", root / "dynamic")
    run(compiler, "-static", source, "-o", root / "static")
    run(compiler, "-c", source, "-o", root / "relocatable.o")
    static = (root / "static").read_bytes()
    relocatable = (root / "relocatable.o").read_bytes()
    # The selected tool's existing directory plays the CUPS dlopen role.
    retained = str(Path(patchelf).parent)
    config = dict(workspaceRoot="source/build/fixture", paths=["jdk"],
                  elfKinds=["runtime"], dlopenDirectories=[retained],
                  readelf=readelf, patchelf=patchelf)

    def invoke(changes=None, base=workspace):
        return run(sys.executable, "-B", adapter, base,
                   json.dumps(config | (changes or {})), common, selector)

    def reject(changes=None, base=workspace):
        try:
            invoke(changes, base)
        except subprocess.CalledProcessError:
            return
        raise AssertionError(f"accepted invalid fixture: {changes}")

    stamp = 1_234_567_890_123_456_789
    for file in root.iterdir():
        os.utime(file, ns=(4_000_000_000_000_000_000, stamp))
    invoke()
    paths = run(patchelf, "--print-rpath", root / "dynamic").stdout.decode().strip().split(":")
    assert retained in paths and "/unused" not in paths
    assert (root / "static").read_bytes() == static
    assert (root / "relocatable.o").read_bytes() == relocatable
    assert all(file.stat().st_mtime_ns == stamp for file in root.iterdir())
    assert (root / "dynamic").stat().st_atime_ns == 4_000_000_000_000_000_000
    # Embedding happens only after shrinking, including native resource files.
    shutil.copy2(root / "dynamic", workspace / "embedded")
    assert run(patchelf, "--print-rpath", workspace / "embedded").stdout.decode().strip().split(":") == paths
    run(root / "dynamic")
    run(root / "static")
    reject({"readelf": failing})
    reject({"patchelf": failing})
    mutation_failure = workspace / "patchelf-mutation-failure"
    mutation_failure.write_text(
        f"#!{sys.executable}\nimport os, sys\n"
        "if sys.argv[1] == '--shrink-rpath': sys.exit(23)\n"
        f"os.execv({patchelf!r}, [{patchelf!r}, *sys.argv[1:]])\n")
    mutation_failure.chmod(0o755)
    reject({"patchelf": str(mutation_failure)})
    for name in ("", "/tmp", "..", "source/../source", "source//build", "source/./build", "missing", "source/build/fixture/jdk/dynamic"):
        reject({"workspaceRoot": name})
    (workspace / "linked").symlink_to(workspace / "source", target_is_directory=True)
    reject({"workspaceRoot": "linked/build/fixture"})
    (stage / "linked-jdk").symlink_to(root, target_is_directory=True)
    for path in ("", "/tmp", "..", "jdk/../jdk", "linked-jdk", "absent"):
        reject({"paths": [path]})
    reject(base=workspace / "linked")
    # Default (no ELF kind scope) deliberately retains legacy ET_REL rejection.
    reject({"elfKinds": None})

    # Installed finalization preserves needed self libraries while selecting libc.
    (root / "self").mkdir()
    library = workspace / "answer.c"
    library.write_text('int answer(void) { return 42; }\n')
    source.write_text('extern int answer(void); int main(void) { return answer() != 42; }\n')
    run(compiler, "-shared", "-fPIC", library, "-o", root / "self/libanswer.so")
    run(compiler, source, "-L" + str(root / "self"), "-lanswer",
        "-Wl,-rpath,$ORIGIN/self", "-o", root / "dynamic-self")
    run(sys.executable, "-B", installed, root, json.dumps(dict(
        paths=["dynamic-self"], readelf=readelf, patchelf=patchelf, interpreter=loader)), common)
    assert str(root / "self") in run(patchelf, "--print-rpath", root / "dynamic-self").stdout.decode().strip().split(":")
    assert run(patchelf, "--print-interpreter", root / "dynamic-self").stdout.decode().strip() == loader
    run(root / "dynamic-self")
