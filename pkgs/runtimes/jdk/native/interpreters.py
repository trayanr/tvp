"""Installed JDK loaders and self-relative library lookup, before provider binding."""
import os
from pathlib import Path
import sys
sys.path.insert(0, sys.argv[3])
from common import elf, files, invocation, preserving_times, tool

root, config = invocation()
for path in files(root, config["paths"]):
    classification = elf(path, config["readelf"])
    if classification is None or not classification[0]:
        continue

    def configure():
        if classification[1]:
            tool(config["patchelf"], "--set-interpreter", config["interpreter"], path)
        original = tool(config["patchelf"], "--print-rpath", path).rstrip("\n")
        directories = []
        for directory in original.split(":") if original else []:
            if "$ORIGIN" in directory or "${ORIGIN}" in directory:
                directory = directory.replace("${ORIGIN}", str(path.parent)).replace("$ORIGIN", str(path.parent))
                directory = str(Path(os.path.normpath(directory)).resolve(strict=True))
                if not Path(directory).is_dir() or not Path(directory).is_relative_to(root):
                    raise ValueError(f"JDK self lookup escapes installed output: {directory}")
            if "$" in directory:
                raise ValueError(f"unsupported JDK lookup variable: {directory}")
            directories.append(directory)
        value = ":".join(directories)
        if value != original:
            tool(config["patchelf"], "--set-rpath", value, path)

    preserving_times(path, configure)
