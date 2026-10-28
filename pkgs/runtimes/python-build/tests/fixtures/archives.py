import bz2
import io
import lzma
import tarfile
import zipfile
import zlib

data = b"42"
for module in (zlib, bz2, lzma):
    assert module.decompress(module.compress(data)) == data
for compression in ("gz", "bz2", "xz"):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w:" + compression) as archive:
        info = tarfile.TarInfo("answer")
        info.size = len(data)
        archive.addfile(info, io.BytesIO(data))
    stream.seek(0)
    with tarfile.open(fileobj=stream, mode="r:*") as archive:
        assert archive.extractfile("answer").read() == data
for compression in (zipfile.ZIP_DEFLATED, zipfile.ZIP_BZIP2, zipfile.ZIP_LZMA):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w", compression=compression) as archive:
        archive.writestr("answer", data)
    with zipfile.ZipFile(stream) as archive:
        assert archive.read("answer") == data
print(data.decode())
