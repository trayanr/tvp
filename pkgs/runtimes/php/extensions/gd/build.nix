args@{
  tvp,
  lib,
  base,
  src,
  version,
  php,
  extensionName,
  phpCompatibility,
  autoconf,
  automake,
  libtool,
  zlib,
  libpng,
  libjpeg-turbo,
  libwebp,
  freetype,
  configureOptions ? [ ],
  patches ? [ ],
  libraries ? [ ],
  loader ? "extension",
  extensionMeta ? { },
  sourceMode ? "archive",
  compression ? "gzip",
}:
final:
import ../build-bundled.nix
  (builtins.removeAttrs args [
    "zlib"
    "libpng"
    "libjpeg-turbo"
    "libwebp"
    "freetype"
  ])
  (
    final
    // {
      configureOptions = final.configureOptions ++ [
        "--enable-gd"
        "--with-jpeg"
        "--with-webp"
        "--with-freetype"
      ];
      libraries = [
        final.zlib
        final.libpng
        final.libjpeg-turbo
        final.libwebp
        final.freetype
      ]
      ++ final.libraries;
    }
  )
// {
  inherit
    zlib
    libpng
    libjpeg-turbo
    libwebp
    freetype
    ;
}
