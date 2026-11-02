"""Internal, serial x86_64 Linux output-file operations, not phase dispatch."""

import json
import os
from pathlib import Path
import stat
import struct
import subprocess
import sys


def invocation():
    root = Path(sys.argv[1])
    if not root.is_absolute() or root.is_symlink() or not root.is_dir():
        raise ValueError(f"expected owned output directory: {root}")
    return root.resolve(strict=True), json.loads(sys.argv[2])


def selected(root, selector, *, link=False):
    # Do not normalize away unsafe components or follow symlinked parents.
    if (not isinstance(selector, str) or not selector or "\0" in selector
            or any(p in ("", ".", "..") for p in selector.split("/"))):
        raise ValueError(f"unsafe output selector: {selector!r}")
    path = root
    parts = selector.split("/")
    for i, part in enumerate(parts):
        path = path / part
        info = path.lstat()
        if stat.S_ISLNK(info.st_mode) and not (link and i == len(parts) - 1):
            raise ValueError(f"symlink output selector: {path}")
    return path


def files(root, selectors):
    seen = set()

    def walk(path):
        info = path.lstat()
        if stat.S_ISLNK(info.st_mode):
            return  # Never traverse or mutate through a discovered symlink.
        if stat.S_ISDIR(info.st_mode):
            for child in sorted(path.iterdir()):
                yield from walk(child)
        elif stat.S_ISREG(info.st_mode):
            identity = (info.st_dev, info.st_ino)
            if identity not in seen:
                seen.add(identity)
                yield path
        else:
            raise ValueError(f"unsupported output file: {path}")

    for selector in selectors:
        yield from walk(selected(root, selector))


def tool(binary, *args):
    if not os.path.isabs(binary):
        raise ValueError(f"expected absolute declared tool: {binary}")
    result = subprocess.run([binary, *map(str, args)], check=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    # Inspection warnings are not a successful classification of malformed ELF.
    if result.stderr:
        raise ValueError(f"{binary}: {result.stderr.decode(errors='replace')}")
    return result.stdout.decode()


def elf(path, readelf):
    with path.open("rb") as stream:
        header = stream.read(64)
    if not header.startswith(b"\x7fELF"):
        return None  # Text and archives are deliberately not supported transforms.
    if len(header) != 64 or header[4:7] != b"\x02\x01\x01":
        raise ValueError(f"expected native ELF64 little-endian: {path}")
    kind, machine, version = struct.unpack_from("<HHI", header, 16)
    if machine != 62 or version != 1 or kind not in (2, 3):
        raise ValueError(f"expected native executable/shared ELF: {path}")
    phoff = struct.unpack_from("<Q", header, 32)[0]
    ehsize, phsize, phnum = struct.unpack_from("<HHH", header, 52)
    if ehsize != 64 or phsize != 56 or not phnum or phnum == 65535:
        raise ValueError(f"invalid/unsupported ELF program headers: {path}")
    size = path.stat().st_size
    if phoff + phsize * phnum > size:
        raise ValueError(f"truncated ELF program headers: {path}")
    dynamic = interpreter = False
    with path.open("rb") as stream:
        stream.seek(phoff)
        for _ in range(phnum):
            record = stream.read(phsize)
            tag, _, offset, _, _, length = struct.unpack_from("<IIQQQQ", record)
            if offset + length > size:
                raise ValueError(f"truncated ELF segment: {path}")
            dynamic |= tag == 2
            interpreter |= tag == 3
    tool(readelf, "--wide", "--file-header", "--program-headers",
         "--section-headers", "--dynamic", path)
    if interpreter and not dynamic:
        raise ValueError(f"ELF interpreter without dynamic section: {path}")
    return dynamic, interpreter


def preserving_times(path, operation):
    info = path.stat()
    operation()
    os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))


def store_directories(paths):
    result = []
    for path in paths:
        if (not isinstance(path, str) or not path.startswith("/nix/store/")
                or any(c in path for c in (":", "\0", "\n"))
                or any(p in ("", ".", "..") for p in path.split("/")[1:])):
            raise ValueError(f"expected existing store directory: {path!r}")
        resolved = Path(path).resolve(strict=True)
        if not resolved.is_dir() or not str(resolved).startswith("/nix/store/"):
            raise ValueError(f"directory resolves outside store: {path}")
        if str(resolved) not in result:
            result.append(str(resolved))
    return result
