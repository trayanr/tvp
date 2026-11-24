"""Backport the libjpeg-turbo guards used by ImageMagick 7.1.1."""

from pathlib import Path
import re

source = Path("coders/jpeg.c")
original = source.read_bytes()
updated = re.sub(
    rb"(?m)^#if defined\(D_LOSSLESS_SUPPORTED\)$",
    b"#if !defined(LIBJPEG_TURBO_VERSION_NUMBER) && defined(D_LOSSLESS_SUPPORTED)",
    original,
)
updated = re.sub(
    rb"(?m)^#if !defined\(C_LOSSLESS_SUPPORTED\)$",
    b"#if defined(LIBJPEG_TURBO_VERSION_NUMBER) || !defined(C_LOSSLESS_SUPPORTED)",
    updated,
)
if updated != original:
    source.write_bytes(updated)
