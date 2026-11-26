"""Select host runtime ELF files before an existing strict output operation.

Foreign ELF payloads remain untouched. Selected host files retain the operation's
complete structural and tool validation, including explicit relocatable selection.
"""

import json
import struct
import subprocess
import sys

sys.path.insert(0, sys.argv[3])
from common import files, invocation  # noqa: E402

root, config = invocation()
selected = []
for path in files(root, config["paths"]):
    with path.open("rb") as stream:
        header = stream.read(64)
    if not header.startswith(b"\x7fELF"):
        continue
    if len(header) < 20:
        raise ValueError(f"truncated ELF identification: {path}")
    if header[4:6] != b"\x02\x01":
        continue
    kind, machine = struct.unpack_from("<HH", header, 16)
    if machine != 62:
        continue
    if kind in (2, 3) or (kind == 1 and config.get("kinds") is not None):
        selected.append(str(path.relative_to(root)))

config["paths"] = selected
if not selected:
    sys.exit(0)
subprocess.run(
    [sys.executable, "-B", sys.argv[4], str(root), json.dumps(config),
     sys.argv[3], *sys.argv[5:]],
    check=True,
)
