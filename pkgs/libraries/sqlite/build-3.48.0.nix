# Serves 3.48.0 onwards.
#
# Built from the canonical Fossil tree rather than the autoconf tarball: the
# tarball is only published back to 3.7.16.2, and its amalgamation is generated
# by exactly the code below.
{
  lib,
  stdenv,
  fetchurl,

  # Native: configure is autosetup, which is written in Tcl, and the
  # amalgamation is assembled by tool/mksqlite3c.tcl.
  tcl,

  readline,

  version,
  sha256,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "sqlite";
  inherit version;

  # Fossil serves a tarball per tag; the requested filename becomes the root
  # directory inside it.
  src = fetchurl {
    name = "sqlite-${version}.tar.gz";
    url = "https://sqlite.org/src/tarball/sqlite-${version}.tar.gz?r=version-${version}";
    inherit sha256;
  };

  nativeBuildInputs = [ tcl ];
  buildInputs = [ readline ];

  # install-tcl targets the first writable dir on tclsh's auto_path, which is
  # inside tcl's own store path.
  makeFlags = [ "TCLLIBDIR=${placeholder "out"}/lib/tcl" ];

  configureFlags = [
    "--all"
    "--with-tclsh=${tcl}/bin/tclsh"
    "--with-readline-header=${readline}/include/readline/readline.h"
  ];

  meta = {
    description = "Self-contained SQL database engine";
    homepage = "https://sqlite.org/";
    license = lib.licenses.publicDomain;
    platforms = lib.platforms.unix;
  };

  passthru = {
    inherit version;
    tvp.deps = {
      inherit tcl readline;
    };
    tvp.cc = stdenv.cc;
    tvp.reportedVersion = version;
    tvp.pkgConfigVersion = version;

    tvp.features = {
      pkgConfig = true;
      prepareV2 = true;
      libVersionFunction = true;
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})
