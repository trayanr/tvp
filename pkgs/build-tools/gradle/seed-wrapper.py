#!@python@
"""Seed the exact verified all.zip; upstream Wrapper verifies and installs it."""
import hashlib
import os
from pathlib import Path

version = "@version@"
filename = f"gradle-{version}-all.zip"
url = f"https://services.gradle.org/distributions/{filename}"
value = int.from_bytes(hashlib.md5(url.encode()).digest(), "big")
encoded = ""
while value:
    value, digit = divmod(value, 36)
    encoded = "0123456789abcdefghijklmnopqrstuvwxyz"[digit] + encoded
home = Path(os.environ.get("GRADLE_USER_HOME", str(Path.home() / ".gradle")))
cache = home / "wrapper" / "dists" / filename.removesuffix(".zip") / encoded
cache.mkdir(parents=True, exist_ok=True)
# Do not overwrite user caches, and let Wrapper create its own success marker.
if not (cache / (filename + ".ok")).exists():
    try:
        (cache / filename).symlink_to("@archive@")
    except FileExistsError:
        pass
