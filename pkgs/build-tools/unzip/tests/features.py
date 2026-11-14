"""Bounded archive semantics; Python is an independent method/Zip64 reader."""
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    entries = archive.infolist()
    assert entries
    if len(sys.argv) > 2:
        assert archive.getinfo("large").compress_type == zipfile.ZIP_BZIP2
        assert archive.getinfo("payload").compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_BZIP2)
        assert archive.read("payload") == b"preserved"
        assert archive.read("large") == bytes(128 * 1024)
    else:
        assert entries[0].extract_version >= 45
        assert archive.read("payload") == b"preserved"
        assert b"PK\x06\x06" in open(sys.argv[1], "rb").read()
