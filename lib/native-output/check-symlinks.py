from pathlib import Path
import os

from common import invocation, selected

root, config = invocation()
for selector in config["paths"]:
    path = selected(root, selector, link=True)
    if not path.is_symlink():
        raise ValueError(f"expected relative output symlink: {path}")
    if Path(os.readlink(path)).is_absolute():
        raise ValueError(f"expected relative output symlink: {path}")
    path.resolve(strict=True).relative_to(root)
