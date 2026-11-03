{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  zlib,
  bzip2,
  patchelf,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "freetype";
  inherit version;
  src = fetchurl {
    url = "https://download.savannah.gnu.org/releases/freetype/freetype-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    pkg-config
    patchelf
  ];
  buildInputs = [
    zlib
    bzip2
  ];
  configureFlags = [
    "--with-zlib=yes"
    "--with-bzip2=yes"
    "--with-png=no"
    "--with-brotli=no"
    "--with-harfbuzz=no"
  ];
  enableParallelBuilding = true;
  meta = {
    description = "Font rendering library with zlib and bzip2 compressed-font support";
    homepage = "https://freetype.org/";
    license = lib.licenses.ftl;
    platforms = [ "x86_64-linux" ];
  };
  passthru = {
    # ft2build.h lives below freetype2. freetype2.pc advertises -lz and -lbz2
    # for static consumers; publish selected development
    # interfaces without executing setup hooks or reading built metadata.
    development = {
      includes = [ "${finalAttrs.finalPackage}/include/freetype2" ];
      libraries = [
        zlib
        bzip2
      ];
    };
    tvp.deps = {
      inherit
        pkg-config
        zlib
        bzip2
        patchelf
        ;
    };
    tvp.cc = stdenv.cc;
    tvp.features = {
      png = false;
      brotli = false;
      harfbuzz = false;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})
