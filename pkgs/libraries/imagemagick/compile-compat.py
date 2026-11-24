"""Repair recorded compile defects in the affected source archives."""

from pathlib import Path
import sys


def replace(name, before, after, count=1):
    path = Path(name)
    source = path.read_bytes()
    if source.count(before) != count:
        raise ValueError(f"{path}: expected {count} occurrence(s) of {before!r}")
    path.write_bytes(source.replace(before, after))


def fix_makefile(version):
    # These maintainer recipes must be parseable even for an ordinary build.
    if version == (6, 6, 1, 10):
        replace("Makefile.in", b"\n  $(MAKE) MEMCHECK=", b"\n\t$(MAKE) MEMCHECK=", count=4)
    else:
        replace(
            "Makefile.in",
            b"drd:\n"
            b"  $(MAKE) MEMCHECK='valgrind --tool=drd --check-stack-var=yes --var-info=yes \\\n"
            b"    --quiet $(VALGRIND_EXTRA_OPTS)' check\n\n",
            b"",
        )
    replace("Makefile.in", b"\n  svn export ", b"\n\tsvn export ")


def fix_legacy_build(version):
    if version <= (6, 5, 5, 10):
        replace(
            "magick/static.c",
            b"analyzeImage(Image **,const int,char **,ExceptionInfo *);",
            b"analyzeImage(Image **,const int,const char **,ExceptionInfo *);",
        )
    if version <= (6, 5, 6, 10):
        replace(
            "coders/avi.c",
            b"#ifdef D_LOSSLESS_SUPPORTED\n            image->interlace=jpeg_info.process",
            b"#if !defined(LIBJPEG_TURBO_VERSION_NUMBER) && defined(D_LOSSLESS_SUPPORTED)\n"
            b"            image->interlace=jpeg_info.process",
        )
    elif version < (6, 6, 1, 10):
        replace(
            "magick/magick.c",
            b"  (void) XComponentGenesis();\n",
            b"#if defined(MAGICKCORE_X11_DELEGATE)\n  (void) XComponentGenesis();\n#endif\n",
        )
    else:
        if version <= (6, 6, 2, 10):
            fix_makefile(version)
        # Modern libpng omits the old far-memory qualifier and uses bytes
        # for the ICC profile returned by png_get_iCCP.
        replace("coders/png.c", b" FARDATA ", b" ", count=48)
        if version <= (6, 6, 6, 10):
            replace(
                "coders/png.c",
                b"      png_charp\n        info,\n        name;",
                b"      png_bytep\n        info;\n\n      png_charp\n        name;",
            )


def fix_elapsed_clock(version):
    component = "magick" if version[0] == 6 else "MagickCore"
    # SOURCE_DATE_EPOCH controls image timestamps. Using it as the current
    # wall clock here can overflow the unlimited lifetime and fail instantly.
    replace(
        f"{component}/timer.c",
        b"  if (epoch_initialized == MagickFalse)\n"
        b"    {\n"
        b"      epoch_initialized=MagickTrue;\n"
        b"      magick_epoch=time((time_t *) NULL);\n"
        b"    }\n"
        b"  return((MagickOffsetType) GetMagickResourceLimit(TimeResource)-\n"
        b"    (GetMagickTime()-magick_epoch));",
        b"  const time_t now=time((time_t *) NULL);\n"
        b"  if (epoch_initialized == MagickFalse)\n"
        b"    {\n"
        b"      epoch_initialized=MagickTrue;\n"
        b"      magick_epoch=now;\n"
        b"    }\n"
        b"  return((MagickOffsetType) GetMagickResourceLimit(TimeResource)-\n"
        b"    ((now > magick_epoch) ? (now-magick_epoch) : 0));",
    )


def fix_jpeg_client_context():
    # Backport the next release's pointer and trace fixes. The JPEG callback
    # must receive the client context itself, rather than the address of its pointer.
    replace(
        "coders/jpeg.c",
        b"jpeg_info->client_data=(void *) &client_info;",
        b"jpeg_info->client_data=(void *) client_info;",
        count=2,
    )
    replace(
        "coders/jpeg.c",
        b"if ((image->debug != MagickFalse) && (level >= jpeg_info->err->trace_level))",
        b"if (level >= jpeg_info->err->trace_level)",
    )
    replace(
        "coders/jpeg.c",
        b'        (void) LogMagickEvent(CoderEvent,GetMagickModule(),\n'
        b'          "[%s] JPEG Trace: \\"%s\\"",image->filename,message);',
        b'        if ((image != (Image *) NULL) && (image->debug != MagickFalse))\n'
        b'          (void) LogMagickEvent(CoderEvent,GetMagickModule(),\n'
        b'            "[%s] JPEG Trace: \\"%s\\"",image->filename,message);',
    )


def main(release):
    version = tuple(map(int, release.split(".")))
    if (6, 5, 4, 10) <= version < (6, 7, 4, 10):
        fix_legacy_build(version)
    elif version == (6, 9, 12, 9):
        fix_jpeg_client_context()
    elif version in {(6, 9, 12, 98), (7, 1, 1, 20)}:
        fix_elapsed_clock(version)
    elif version == (7, 0, 8, 17):
        # Use the ReadOptions setter, as in the following upstream release.
        replace("Magick++/lib/Magick++/STL.h", b"options.ping=true;", b"options.ping(true);", count=2)
    else:
        raise ValueError(f"ImageMagick {release} has no additional compile fix")


if __name__ == "__main__":
    _, release = sys.argv
    main(release)
