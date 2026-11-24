"""Apply source compatibility fixes to the ImageMagick releases that need them."""

from pathlib import Path
import re
import sys


def replace(path, before, after, count=1):
    source = Path(path)
    contents = source.read_bytes()
    if contents.count(before) != count:
        raise ValueError(f"{path}: expected {count} occurrence(s) of {before!r}")
    source.write_bytes(contents.replace(before, after))


def restore_gzip_handle_type():
    # These releases store gzopen's handle in their shared FILE pointer.
    # Convert it back at zlib call sites, including the gzgetc macro.
    source = Path("magick/blob.c")
    contents, count = re.subn(
        rb"\b(gz(?:close|error|flush|getc|putc|read|seek|tell|write)\()image->blob->file\b",
        rb"\1(gzFile) image->blob->file",
        source.read_bytes(),
    )
    if count != 11:
        raise ValueError(f"{source}: expected 11 legacy gzFile call sites, found {count}")
    source.write_bytes(contents)


def fix_disabled_opencl_stub():
    # Match the no-argument declaration in opencl.h and the enabled stub.
    replace(
        "magick/opencl.c",
        b"GetDefaultOpenCLEnv(\n  ExceptionInfo *magick_unused(exception))\n"
        b"{\n  magick_unreferenced(exception);\n",
        b"GetDefaultOpenCLEnv(void)\n{\n",
    )


def install_present_html_files():
    # Some documentation directories have only subdirectories. The glob
    # remains literal in those directories, so filter it before installing.
    replace(
        "Makefile.in",
        b"for file in $$docsrcdir/*.* ; do",
        b'for file in $$docsrcdir/*.* ; do test -f "$$file" || continue;',
    )


def main(release):
    version = tuple(map(int, release.split(".")))
    if (6, 5, 4, 10) <= version < (6, 7, 5, 10):
        restore_gzip_handle_type()
    elif (6, 8, 7, 10) <= version < (6, 9, 2, 10):
        fix_disabled_opencl_stub()
    elif version == (6, 9, 9, 1):
        replace(
            "magick/enhance.c",
            b"if (stretch_map != (double *) NULL)\n"
            b"        stretch_map=(double *) RelinquishMagickMemory(stretch_map);\n"
            b"      if (histogram != (double *) NULL)\n"
            b"        histogram=(double *) RelinquishMagickMemory(histogram);",
            b"if (stretch_map != (QuantumPixelPacket *) NULL)\n"
            b"        stretch_map=(QuantumPixelPacket *) RelinquishMagickMemory(stretch_map);\n"
            b"      if (histogram != (MagickPixelPacket *) NULL)\n"
            b"        histogram=(MagickPixelPacket *) RelinquishMagickMemory(histogram);",
        )
    elif version == (6, 9, 10, 81):
        replace(
            "magick/magick-type.h",
            b'#include "magick/magick-config.h"\n',
            b'#include "magick/magick-config.h"\n#include <stdint.h>\n',
        )
    elif version == (6, 9, 11, 17):
        # StringInfo.path is a fixed-size array in this release.
        replace(
            "magick/string.c",
            b"CloneString(&clone_info->path,string_info->path);",
            b"CopyMagickString(clone_info->path,string_info->path,MaxTextExtent);",
        )
    elif (6, 9, 13, 53) <= version <= (6, 9, 13, 61):
        install_present_html_files()
    elif version == (7, 1, 0, 52):
        replace(
            "MagickCore/magic.c",
            b"IsMagicCacheInstantiated(exception)",
            b"IsMagicCacheInstantiated()",
            count=2,
        )
    else:
        raise ValueError(f"ImageMagick {release} has no source compatibility fix")


if __name__ == "__main__":
    _, release = sys.argv
    main(release)
