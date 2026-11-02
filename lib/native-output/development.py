from common import invocation, selected, store_directories

root, config = invocation()
# Validate directories without canonicalizing the selected dependency spelling.
store_directories(config["libraries"])
support = root / "nix-support"
if not support.exists() and not support.is_symlink():
    support.mkdir()
selected(root, "nix-support")
if not support.is_dir():
    raise ValueError("nix-support is not a directory")
path = support / "propagated-build-inputs"
if path.exists() or path.is_symlink():
    selected(root, "nix-support/propagated-build-inputs")
    if not path.is_file() or path.stat().st_nlink != 1:
        raise ValueError("expected unlinked regular development metadata")
path.write_bytes(b"".join(p.encode() + b" " for p in config["libraries"]))
