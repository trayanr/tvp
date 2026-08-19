# Serves 1.7.3 to 1.8.3 — the generation before gdbm moved to automake. The
# Makefile installs into directories it never creates, hardcodes the install
# ownership, ships no check target, and knows nothing of
# --enable-libgdbm-compat: dbm and ndbm are either inside libgdbm or in a
# libgdbm_compat that `all` builds unconditionally.
{
  lib,
  stdenv,
  fetchurl,

  version,
  sha256,
  patches ? [ ],

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
let
  # dbm and ndbm are split into libgdbm_compat at 1.8.1; below that they are
  # linked into libgdbm itself.
  compatLib = lib.versionAtLeast version "1.8.1";

  # libtool, and with it a shared library, arrives at 1.8.0.
  shared = lib.versionAtLeast version "1.8.0";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "gdbm";
  inherit version patches;

  src = fetchurl {
    url = "https://ftp.gnu.org/gnu/gdbm/gdbm-${version}.tar.gz";
    inherit sha256;
  };

  # `install -o bin -g bin` needs a user the sandbox does not have. Unpacking
  # gives every file one mtime, so make also regenerates the gdbm.info the
  # tarball already ships, which would need makeinfo.
  postPatch = ''
    sed -i 's| -o $(BINOWN) -g $(BINGRP)||g' Makefile.in
    touch gdbm.info
  '';

  enableParallelBuilding = true;

  preInstall = ''
    mkdir -p "$out/lib" "$out/include" "$out/share/man/man3" "$out/share/info"
  '';

  installTargets = [
    "install"
    "install-compat"
  ];

  installFlags = [
    "prefix=${placeholder "out"}"
    "libdir=${placeholder "out"}/lib"
    "includedir=${placeholder "out"}/include"
    "man3dir=${placeholder "out"}/share/man/man3"
    "infodir=${placeholder "out"}/share/info"
  ];

  # Consumers written against the traditional layout include <gdbm/ndbm.h>.
  postInstall = ''
    install -dm755 "$out/include/gdbm"
    ln -s ../dbm.h ../gdbm.h ../ndbm.h "$out/include/gdbm/"
  '';

  meta = {
    description = "GNU dbm key/value database library";
    homepage = "https://www.gnu.org/software/gdbm/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };

  passthru = {
    inherit version;
    tvp.deps = { };

    tvp.features = {
      inherit compatLib shared;
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})
