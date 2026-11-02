import os

from common import elf, files, invocation, tool

root, config = invocation()
forbidden = [os.environ[key] for key in ("NIX_BUILD_TOP", "TMPDIR")]
if any(not p.startswith("/") or p == "/" for p in forbidden):
    raise ValueError("expected absolute shared and per-step build directories")


def audit(value, path):
    # Also catches an ancestor lookup directory (e.g. /build), without scanning
    # unrelated ELF strings such as intentionally retained assertion filenames.
    if (not value or not value.startswith("/") or "$" in value
            or any(p in ("", ".", "..") for p in value.split("/")[1:])):
        raise ValueError(f"unsupported runtime lookup path {value!r}: {path}")
    resolved = os.path.realpath(value)
    for build in forbidden:
        build = os.path.realpath(build)
        if os.path.commonpath([resolved, build]) in (resolved, build):
            raise ValueError(f"forbidden build lookup path {value!r}: {path}")
    if not os.path.exists(value):
        raise ValueError(f"nonexistent runtime lookup path {value!r}: {path}")


for path in files(root, config["paths"]):
    classification = elf(path, config["readelf"])
    if classification is None or not classification[0]:
        continue
    rpath = tool(config["patchelf"], "--print-rpath", path).rstrip("\n")
    for directory in rpath.split(":") if rpath else []:
        audit(directory, path)
    if classification[1]:
        audit(tool(config["patchelf"], "--print-interpreter", path).rstrip("\n"), path)
    # DT_NEEDED may itself encode a runtime pathname.
    for needed in tool(config["patchelf"], "--print-needed", path).splitlines():
        if "/" in needed:
            audit(needed, path)
