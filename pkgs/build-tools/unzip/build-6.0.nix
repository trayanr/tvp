{
  lib,
  stdenv,
  fetchurl,
  bash,
  patchelf,
  cflags,
  hardeningDisable,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "unzip";
  inherit version hardeningDisable;
  env.NIX_CFLAGS_COMPILE = cflags;
  src = fetchurl {
    url = "https://downloads.sourceforge.net/infozip/unzip60.tar.gz";
    inherit sha256;
  };
  nativeBuildInputs = [ patchelf ];
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
  postInstall = ''
    install -Dm644 ${./setup-hook.sh} "$out/nix-support/setup-hook"
  '';
  meta = {
    description = "Info-ZIP archive extractor";
    homepage = "https://infozip.sourceforge.net/";
    license = lib.licenses.info-zip;
    platforms = [ "x86_64-linux" ];
    mainProgram = "unzip";
  };
  passthru = {
    tvp.deps = {
      inherit bash patchelf;
    };
    tests = mkTests finalAttrs.finalPackage;
  };
})
