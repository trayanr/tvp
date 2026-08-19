# Serves 4.2 to 5.7 — the generation before ncurses installed pkg-config files.
# --enable-pc-files arrives at 5.8, and with it the pkg-config dependency, so
# below that there is nothing to declare and nothing to configure.
#
# --without-tests also arrives at 5.8, so test/ is dropped from SRC_SUBDIRS
# instead. Those are demo programs, never installed; blue.c shifts a 32-bit
# chtype past its width and testcurs.c passes a variable to printw.
{
  lib,
  stdenv,
  fetchurl,

  version,
  sha256,

  hardeningDisable ? [ ],

  # 5.0 … 5.2 include <strstream.h> unconditionally, from the pre-standard C++
  # library. 5.3 made it conditional on HAVE_STRSTREAM_H.
  cxxBinding ? true,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
let
  # 5.1 introduced LIB_SUFFIX, which renames the wide build to ncursesw.
  # 4.2 and 5.0 compile the same code into a library still called ncurses.
  libName = if lib.versionAtLeast version "5.1" then "ncursesw" else "ncurses";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ncurses";
  inherit version;

  src = fetchurl {
    url = "https://ftp.gnu.org/gnu/ncurses/ncurses-${version}.tar.gz";
    inherit sha256;
  };

  postPatch = ''
    sed -i 's|SRC_SUBDIRS="$SRC_SUBDIRS misc test"|SRC_SUBDIRS="$SRC_SUBDIRS misc"|' configure
  '';

  inherit hardeningDisable;

  configureFlags = [
    "--with-shared"
    "--enable-widec"
    "--without-debug"
  ] ++ lib.optional (!cxxBinding) "--without-cxx-binding";

  meta = {
    description = "Free software emulation of curses";
    homepage = "https://invisible-island.net/ncurses/";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };

  passthru = {
    inherit version;
    tvp.deps = { };
    tvp.cc = stdenv.cc;

    tvp.features = {
      widec = true;
      inherit libName;
      pkgConfig = false;
      # 4.2 ships a c++ demo, not a binding library; libncurses++ arrives at 5.0.
      cxx = cxxBinding && lib.versionAtLeast version "5.0";
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})
