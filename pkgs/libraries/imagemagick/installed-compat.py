"""Repair released installation metadata before relocating ImageMagick."""

import os
from pathlib import Path
import sys


def relocate_utility_links(root, artifact):
    repairs = []
    for link in sorted((root / "bin").iterdir()):
        if not link.is_symlink():
            continue
        target = link.readlink()
        if not target.is_absolute() or not target.is_relative_to(artifact):
            continue
        installed = root / target.relative_to(artifact)
        if not installed.resolve(strict=True).is_relative_to(root):
            raise ValueError(f"Utility link escapes the installed package: {link}")
        repairs.append((link, os.path.relpath(installed, link.parent)))
    if not repairs:
        raise ValueError("Expected utility links into the copied build artifact")
    for link, target in repairs:
        link.unlink()
        link.symlink_to(target)


def fix_wand_requires(root):
    # Upstream corrected this delimiter in the next release.
    pkgconfig = root / "lib" / "pkgconfig"
    if not (pkgconfig / "MagickCore-6.Q16.pc").is_file():
        raise ValueError("Expected the installed MagickCore-6.Q16 module")
    before = b"\nRequires: MagickCore.6.Q16\n"
    after = b"\nRequires: MagickCore-6.Q16\n"
    for name in ("MagickWand.pc", "MagickWand-6.Q16.pc"):
        path = pkgconfig / name
        contents = path.read_bytes()
        if contents.count(before) != 1:
            raise ValueError(f"Expected the broken MagickCore requirement in {path}")
        path.write_bytes(contents.replace(before, after))


if __name__ == "__main__":
    _, version, root, artifact = sys.argv
    if version == "6.8.3.10":
        relocate_utility_links(Path(root), Path(artifact))
    elif version == "6.9.10.54":
        fix_wand_requires(Path(root))
    else:
        raise ValueError(f"ImageMagick {version} has no installation repair")
