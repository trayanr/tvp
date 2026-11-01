{
  lib,
  stdenv,
  fetchurl,
  bash,
  bzip2,
  patchelf,
  hardeningDisable,
  cflags ? "",
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "zip";
  inherit version;
  inherit hardeningDisable;
  env.NIX_CFLAGS_COMPILE = cflags;
  src = fetchurl {
    url = "https://downloads.sourceforge.net/infozip/zip30.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [ patchelf ];
  buildInputs = [ bzip2 ];
  dontConfigure = true;
  preBuild = ''
    patchShebangs unix/configure
    export SHELL='${bash}/bin/bash'
  '';
  makefile = "unix/Makefile";
  buildFlags = [ "generic" ];
  makeFlags = [
    "prefix=$(out)"
    "BINDIR=$(out)/bin"
    "MANDIR=$(out)/share/man/man1"
    "CC=cc"
  ];
  meta = {
    description = "Info-ZIP archive creator";
    homepage = "https://infozip.sourceforge.net/";
    license = lib.licenses.info-zip;
    platforms = [ "x86_64-linux" ];
    mainProgram = "zip";
  };
  passthru = {
    tvp.deps = {
      inherit bash bzip2 patchelf;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})
