"""Positive native ELF selection around the unchanged runtime-only operations.

Relocatable objects are validated even when excluded. Only strip accepts them;
RPATH operations receive validated runtime ELF and never see ET_REL.
"""
import json
from pathlib import Path
import struct
import subprocess
import sys

sys.path.insert(0, sys.argv[3])
from common import elf, files, invocation, tool  # noqa: E402

root, config = invocation()
kinds = config.pop("kinds")
operation = sys.argv[4]
if (not isinstance(kinds, list) or not kinds or len(set(kinds)) != len(kinds)
        or any(k not in ("runtime", "relocatable") for k in kinds)):
    raise ValueError("expected nonempty distinct ELF kinds: runtime, relocatable")
if operation not in ("strip", "rpaths", "check-paths"):
    raise ValueError("unsupported ELF operation")
if operation != "strip" and "relocatable" in kinds:
    raise ValueError("relocatable ELF supports stripping only")
runtime = []
for path in files(root, config["paths"]):
    with path.open("rb") as stream:
        header = stream.read(64)
    if not header.startswith(b"\x7fELF"):
        continue
    if len(header) != 64 or header[4:7] != b"\x02\x01\x01":
        raise ValueError(f"expected native ELF64 little-endian: {path}")
    kind, machine, version = struct.unpack_from("<HHI", header, 16)
    if kind == 1:
        ehsize = struct.unpack_from("<H", header, 52)[0]
        shoff = struct.unpack_from("<Q", header, 40)[0]
        shsize, shnum = struct.unpack_from("<HH", header, 58)
        if (machine != 62 or version != 1 or ehsize != 64 or shsize != 64
                or not shnum or shoff + shsize * shnum > path.stat().st_size):
            raise ValueError(f"invalid/unsupported native relocatable ELF: {path}")
        tool(config["readelf"], "--wide", "--file-header", "--section-headers", path)
        if "relocatable" in kinds:
            tool(config["strip"], *config["flags"], "--", path)
    else:
        elf(path, config["readelf"])  # Strict runtime validation, including excluded files.
        if "runtime" in kinds:
            runtime.append(str(path.relative_to(root)))
config["paths"] = runtime
subprocess.run([sys.executable, "-B", str(Path(sys.argv[3]) / (operation + ".py")),
                str(root), json.dumps(config)], check=True)
