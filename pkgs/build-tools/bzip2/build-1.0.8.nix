# Serves 1.0.8 onwards.
{
  lib,
  stdenv,
  fetchurl,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "bzip2";
  inherit version;
  src = fetchurl {
    url = "https://sourceware.org/pub/bzip2/bzip2-${version}.tar.gz";
    inherit sha256;
  };
  buildInputs = [ ];
  enableParallelBuilding = true;
  configureFlags = [ ];

  dontConfigure = true;
  buildPhase = ''
    runHook preBuild
    make -j"$NIX_BUILD_CORES" -f Makefile-libbz2_so CC=cc
    make -j"$NIX_BUILD_CORES" CC=cc
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    make install PREFIX="$out"
    cp libbz2.so.1.0.8 "$out/lib/"
    ln -s libbz2.so.1.0.8 "$out/lib/libbz2.so.1.0"
    ln -s libbz2.so.1.0 "$out/lib/libbz2.so.1"
    ln -s libbz2.so.1.0 "$out/lib/libbz2.so"
    runHook postInstall
  '';
  meta = {
    description = "Bzip2 compression utility and library";
    license = lib.licenses.bsdOriginal;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = { };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})
