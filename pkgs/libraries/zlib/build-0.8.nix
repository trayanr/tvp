# Serves 0.8 to 0.99 — named by the repo ordering, under which 0.8 sorts below
# 0.71; these releases number as decimals, so 0.71 is in fact the earliest. These releases ship no configure script and no install
# target: the Makefile builds libgz.a and stops, so the install is written here.
{
  lib,
  stdenv,
  fetchurl,

  version,
  sha256,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "zlib";
  inherit version;

  src = fetchurl {
    url = "https://zlib.net/fossils/zlib-${version}.tar.gz";
    inherit sha256;
  };

  dontConfigure = true;

  makeFlags = [
    "CC=cc"
    "libgz.a"
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib" "$out/include"
    cp libgz.a "$out/lib"
    cp zlib.h zconf.h "$out/include"
    runHook postInstall
  '';

  meta = {
    description = "Lossless data-compression library implementing the DEFLATE algorithm";
    homepage = "https://zlib.net/";
    license = lib.licenses.zlib;
    platforms = lib.platforms.unix;
  };

  passthru = {
    inherit version;
    tvp.deps = { };
    tvp.reportedVersion = version;

    # The archive is libgz.a until 1.0, there is no zlibVersion() until 1.0.5,
    # no zlib.pc until 1.2.3.1 and no shared library at all.
    tvp.features = {
      libName = "gz";
      versionFunction = false;
      compress2 = false;
      pkgConfig = false;
      static = false;
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})
