# Serves 1.5.6 onwards.
{
  lib,
  stdenv,
  fetchurl,
  zlib,
  xz,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "zstd";
  inherit version;
  src = fetchurl {
    url = "https://github.com/facebook/zstd/releases/download/v${version}/zstd-${version}.tar.gz";
    inherit sha256;
  };
  buildInputs = [
    zlib
    xz
  ];
  dontConfigure = true;
  enableParallelBuilding = true;
  makeFlags = [
    "PREFIX=${placeholder "out"}"
    # Avoid autodetecting optional codecs from an incidental build environment.
    # gzip and xz use TVP libraries; lz4 is not a declared dependency.
    "HAVE_ZLIB=1"
    "HAVE_LZMA=1"
    "HAVE_LZ4=0"
  ];
  meta = {
    description = "Zstandard compression library and command-line tools";
    homepage = "https://facebook.github.io/zstd/";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
    mainProgram = "zstd";
  };
  passthru = {
    tvp.deps = {
      inherit zlib xz;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})
