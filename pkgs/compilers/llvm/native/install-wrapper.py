"""Install a Clang driver after validating target layout and output ownership."""
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile


def fail(message):
    raise ValueError("TVP Clang installer: " + message)


def private_directory(path):
    if not path.is_absolute() or ".." in path.parts:
        fail("expected an absolute private directory")
    current = Path(path.anchor)
    for part in path.parts[1:]:
        current /= part
        if not stat.S_ISDIR(current.lstat().st_mode):
            fail("non-directory or symlink parent: " + str(current))


def compiler_alias(path, directory):
    seen = set()
    while True:
        if path.parent != directory:
            fail("compiler alias leaves its bin directory: " + str(path))
        if path in seen:
            fail("compiler alias cycle")
        seen.add(path)
        info = path.lstat()
        if not stat.S_ISLNK(info.st_mode):
            if not stat.S_ISREG(info.st_mode):
                fail("compiler is not a regular file")
            return path
        target = os.readlink(path)
        path = Path(os.path.normpath(target if os.path.isabs(target) else path.parent / target))


def main():
    root, template = map(Path, sys.argv[1:3])
    config = json.loads(sys.argv[3])
    private_directory(root)
    directory = root / "bin"
    private_directory(directory)
    support = root / "nix-support"
    if os.path.lexists(support):
        private_directory(support)
    empty = support / "empty-sysroot"
    if os.path.lexists(empty):
        private_directory(empty)
        if any(empty.iterdir()):
            fail("empty-sysroot is not empty")
    for name in ("bash", "gcc", "gccRuntime", "cxxRuntime", "libc", "bintools", "loader"):
        value = config.get(name)
        if not isinstance(value, str) or not re.fullmatch(r"/[A-Za-z0-9_./+-]+", value):
            fail("invalid explicit provider path: " + name)

    gcc = Path(config["gcc"]).resolve(strict=True)
    env = os.environ.copy()
    for name in ("GCC_EXEC_PREFIX", "COMPILER_PATH", "LIBRARY_PATH", "CPATH",
                 "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH"):
        env.pop(name, None)

    def query(option):
        return subprocess.check_output([str(gcc / "bin/gcc"), option],
                                       env=env, text=True).strip()

    # GCC relocates runtime archives independently of its compiler installation.
    # The intrinsic include directory identifies the latter for Clang discovery.
    include = Path(query("-print-file-name=include")).resolve(strict=True)
    if not include.is_dir() or include.name != "include" or not include.is_relative_to(gcc):
        fail("GCC did not report an owned intrinsic include directory")
    version, triplet = query("-dumpfullversion"), query("-dumpmachine")
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)*", version) or not re.fullmatch(r"[A-Za-z0-9_.-]+", triplet):
        fail("unsupported GCC version/triplet")
    headers = gcc / "include/c++" / version
    if not (headers / "iostream").is_file() or not (headers / triplet / "bits/c++config.h").is_file():
        fail("selected GCC lacks the matching libstdc++ headers")
    gcc_runtime, cxx_runtime = Path(config["gccRuntime"]), Path(config["cxxRuntime"])
    for provider, names in ((gcc_runtime, ("libgcc.a", "crtbegin.o", "crtend.o")),
                            (cxx_runtime, ("libstdc++.so",))):
        for name in names:
            if not (provider / "lib" / name).is_file():
                fail("missing selected runtime file: " + str(provider / "lib" / name))
    # Separate split outputs are supported. Overlapping full providers must agree
    # on their files, otherwise a generic -L/RPATH order would silently pick one.
    if gcc_runtime != cxx_runtime:
        for name in ("libgcc.a", "libgcc_s.so.1", "libstdc++.so", "libstdc++.so.6", "libstdc++.a"):
            a, b = gcc_runtime / "lib" / name, cxx_runtime / "lib" / name
            if a.exists() and b.exists() and a.resolve() != b.resolve():
                fail("conflicting overlapping runtime providers: " + name)

    compiler = compiler_alias(directory / "clang", directory)
    info = compiler.lstat()
    inode = (info.st_dev, info.st_ino)
    regular = []
    aliases = {directory / "clang", compiler}
    for entry in directory.iterdir():
        item = entry.lstat()
        if stat.S_ISREG(item.st_mode) and (item.st_dev, item.st_ino) == inode:
            regular.append(entry)
            aliases.add(entry)
        elif stat.S_ISLNK(item.st_mode) and entry.name.startswith("clang"):
            try:
                target = entry.resolve(strict=True)
            except (OSError, RuntimeError):
                continue
            if target == compiler:
                compiler_alias(entry, directory)
                aliases.add(entry)
    if len(regular) != info.st_nlink:
        fail("compiler has hardlinks outside the owned bin directory")
    cxx = directory / "clang++"
    if os.path.lexists(cxx) and compiler_alias(cxx, directory) != compiler:
        # A hardlinked alias has another pathname but the same owned inode.
        cxx_info = cxx.stat()
        if (cxx_info.st_dev, cxx_info.st_ino) != inode:
            fail("clang++ collides with another installed program")
    aliases.add(cxx)
    hidden = directory / ".clang-unwrapped"
    receipt = support / "target-providers.json"
    if os.path.lexists(hidden) or os.path.lexists(receipt):
        fail("driver or provider receipt already installed")

    view = support / "gcc"
    if os.path.lexists(view):
        fail("GCC installation view already exists")
    install_dir = view / "lib/gcc" / triplet / version
    config.update(gccInstallDir=str(install_dir), gccSourceInstallDir=str(include.parent), gccVersion=version,
                  gccTriplet=triplet, emptyRoot=str(empty), clang=str(hidden))
    text = template.read_text()

    def substitute(match):
        key = match.group(1)
        if key not in config:
            fail("unresolved template placeholder: " + key)
        value = config[key]
        if not isinstance(value, str) or not re.fullmatch(r"/?[A-Za-z0-9_./+-]+", value):
            fail("unsafe template value: " + key)
        return value

    text = re.sub(r"@([A-Za-z_][A-Za-z0-9_-]*)@", substitute, text)

    # Structural validation and rendering are complete before output mutation.
    # Stage files, then replace the public wrapper and every owned compiler alias.
    support.mkdir(exist_ok=True)
    empty.mkdir(exist_ok=True)
    staged = []
    try:
        # Clang requires startup objects beside GCC's intrinsic headers. The
        # selected GCC stores those in its runtime output, so expose a small
        # standard GCC layout without copying or modifying any provider.
        layout = Path(tempfile.mkdtemp(prefix=".gcc-view-", dir=support))
        staged.append(layout)
        internal = layout / "lib/gcc" / triplet / version
        internal.mkdir(parents=True)
        (internal / "include").symlink_to(include)
        if (include.parent / "include-fixed").is_dir():
            (internal / "include-fixed").symlink_to(include.parent / "include-fixed")
        cxx_headers = layout / "include/c++"
        cxx_headers.mkdir(parents=True)
        (cxx_headers / version).symlink_to(headers)
        runtime_files = {
            gcc_runtime: ("crtbegin.o", "crtbeginS.o", "crtbeginT.o", "crtend.o", "crtendS.o",
                          "libgcc.a", "libgcc_eh.a", "libgcc_s.so", "libgcc_s.so.1"),
        }
        for provider, names in runtime_files.items():
            for name in names:
                source = provider / "lib" / name
                if source.is_file():
                    (internal / name).symlink_to(source)
        for name in ("libstdc++.so", "libstdc++.so.6", "libstdc++.a", "libsupc++.a"):
            source = cxx_runtime / "lib" / name
            if source.is_file():
                (internal / name).symlink_to(source)
        fd, name = tempfile.mkstemp(prefix=".tvp-clang-", dir=directory)
        wrapper = Path(name)
        staged.append(wrapper)
        with os.fdopen(fd, "w") as stream:
            stream.write(text)
        wrapper.chmod(0o755)
        fd, name = tempfile.mkstemp(prefix=".target-providers-", dir=support)
        metadata = Path(name)
        staged.append(metadata)
        with os.fdopen(fd, "w") as stream:
            stream.write(json.dumps(config, indent=2) + "\n")
        links = []
        for alias in sorted(aliases - {directory / "clang"}):
            fd, name = tempfile.mkstemp(prefix=".clang-alias-", dir=directory)
            os.close(fd)
            link = Path(name)
            link.unlink()
            # clang-cl has upstream CL/SDK semantics, not the native GNU wrapper
            # flag/sysroot protocol. A direct alias preserves its argv[0] mode.
            link.symlink_to(".clang-unwrapped" if alias.name.startswith("clang-cl") else "clang")
            staged.append(link)
            links.append((link, alias))
        layout.replace(view)
        compiler.rename(hidden)
        wrapper.replace(directory / "clang")
        for link, alias in links:
            link.replace(alias)
        metadata.replace(receipt)
    finally:
        for path in staged:
            if path.is_dir() and not path.is_symlink():
                shutil.rmtree(path)
            else:
                path.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
