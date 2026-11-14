"""Check the installed version nodes against the pinned archive's ELF map.

This is a symbol-version regression check, not a complete ABI comparison.
The 1.2.5.1 parent-node correction changes inheritance, not the declared nodes.
"""
import re
import subprocess
import sys
import tarfile


def inspect(archive, library, readelf):
    with tarfile.open(archive, "r:gz") as source:
        maps = [m for m in source.getmembers()
                if m.name.count("/") == 1 and m.name.endswith("/zlib.map")]
        if len(maps) > 1 or any(not m.isfile() for m in maps):
            raise ValueError("expected at most one regular upstream version map")
        text = source.extractfile(maps[0]).read().decode("ascii") if maps else ""
    names = re.findall(r"^\s*(ZLIB_[0-9.]+)\s*\{", text, re.MULTILINE)
    if maps and (not names or len(names) != len(set(names))):
        raise ValueError("invalid upstream version-node declarations")

    def read(*args):
        result = subprocess.run([readelf, "--wide", *args, str(library)],
                                capture_output=True, text=True, timeout=10)
        if result.returncode != 0 or result.stderr:
            raise ValueError(("ELF inspection failed", result.returncode, result.stderr))
        return result.stdout

    versions = read("--version-info")
    definitions = versions.split("Version definition section", 1)[-1] if "Version definition section" in versions else ""
    definitions = definitions.split("Version needs section", 1)[0]
    actual = re.findall(r"Name:\s+(ZLIB_[0-9.]+)(?=\s|$)", definitions)
    if set(actual) != set(names) or len(actual) != len(names):
        raise ValueError(("Zlib version nodes differ", sorted(names), sorted(actual)))
    symbols = read("--dyn-syms")
    if names and not re.search(r"\bcompressBound@@ZLIB_1\.2\.0(?=\s|$)", symbols):
        raise ValueError("compressBound lacks its upstream default symbol version")
    return {"versionNodes": sorted(actual)}


if __name__ == "__main__":
    inspect(*sys.argv[1:])
    print("ok")
