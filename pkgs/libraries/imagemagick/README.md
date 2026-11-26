# ImageMagick build features

The default Linux build uses HDRI, OpenMP, the X11 libraries, PerlMagick,
libxml2 and the native SVG renderer, Fontconfig, FreeType, TIFF, JPEG, and
bzip2/zlib. The same coder implementations are linked into MagickCore.
The Perl module is installed under `lib/perl5` and can be used with the recipe's
selected Perl and `PERL5LIB` set to that directory.

Some integrations depend on the release's configure support:

| Integration | First packaged release with the matching provider interface |
| --- | --- |
| LittleCMS 2 | 6.6.0-10 |
| XZ | 6.6.6-10 |
| WebP | 6.6.8-10 |
| OpenJPEG | 6.8.8-10 |
| Zstandard | 6.9.10-13 or 7.0.8-13 |
| libzip | 7.0.10-62 |

ImageMagick 6.5.4-10 through 6.6.0-10 access the public `png_info` layout from
older libpng. TVP's libpng 1.6 makes it opaque. Those builds retain the PNM
check and need a compatible historical libpng provider or a source backport
to enable PNG. The early releases that predate LittleCMS 2 and OpenJPEG also
need LittleCMS 1 and JasPer respectively.

Additional delegates need packaged providers and release-appropriate wiring.
These include Ghostscript for PDF/PostScript, librsvg and Cairo for the alternate
SVG renderer, Pango and libraqm for additional text rendering, and the format
libraries for AVIF/HEIF, JPEG XL, Ultra HDR, camera RAW, OpenEXR, JBIG, DjVu,
WMF, and FlashPix. FFTW, Graphviz, and OpenCL also need providers, including an
ICD loader and a runtime driver for OpenCL. Fontconfig discovery uses the fonts
available in the user's runtime environment.

TVP's package `.override` can select a narrower dependency set. For example,
`imagemagick.override { perl = null; libx11 = null; }` omits PerlMagick and X11.
