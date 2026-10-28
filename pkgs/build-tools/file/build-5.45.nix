# Serves 5.45 onwards.
{
  lib,
  stdenv,
  fetchurl,
  zlib,
  xz,
  bzip2,
  zstd,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "file";
  inherit version;
  src = fetchurl {
    url = "https://astron.com/pub/file/file-${version}.tar.gz";
    inherit sha256;
  };
  buildInputs = [
    zlib
    xz
    bzip2
    zstd
  ];
  enableParallelBuilding = true;
  configureFlags = [ ];

  meta = {
    description = "File type identification utility and libmagic";
    license = lib.licenses.bsd2;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit
        zlib
        xz
        bzip2
        zstd
        ;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})
