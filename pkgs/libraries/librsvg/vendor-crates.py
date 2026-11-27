"""Prepare Cargo's offline directory source from release-lock-pinned archives."""

import json
from pathlib import Path, PurePosixPath
import sys
import tarfile


def main():
    crates = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    vendor = Path("vendor")
    vendor.mkdir()

    for crate in crates:
        name = crate["directory"]
        with tarfile.open(crate["file"], "r:gz") as archive:
            members = archive.getmembers()
            if not members or any(
                not PurePosixPath(member.name).parts
                or PurePosixPath(member.name).parts[0] != name
                for member in members
            ):
                raise ValueError(f"Unexpected source archive layout for {name}")
            archive.extractall(vendor, members=members, filter="data")

        root = vendor / name
        if not (root / "Cargo.toml").is_file():
            raise ValueError(f"Missing Cargo.toml for {name}")
        (root / ".cargo-checksum.json").write_text(
            json.dumps({"package": crate["checksum"], "files": {}}),
            encoding="utf-8",
        )

    config = Path(".cargo")
    config.mkdir(exist_ok=True)
    (config / "config.toml").write_text(
        '[source.crates-io]\nreplace-with = "vendored-sources"\n\n'
        '[source.vendored-sources]\ndirectory = "vendor"\n',
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
