# Serves 4.2 to 5.7 — the generation before ncurses installed pkg-config files.
# --enable-pc-files arrives at 5.8, and with it the pkg-config dependency, so
# this builder declares only the platform-script updater.
#
# --without-tests also arrives at 5.8, so test/ is dropped from SRC_SUBDIRS
# instead. Those are demo programs, never installed; blue.c shifts a 32-bit
# chtype past its width and testcurs.c passes a variable to printw.
{
  lib,
  stdenv,
  fetchurl,
  gnu-config,

  version,
  sha256,
  patches ? [ ],

  hardeningDisable ? [ ],
  cStandard ? null,
  cxxStandard ? null,

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
    urls = [
      "https://mirrors.kernel.org/gnu/ncurses/ncurses-${version}.tar.gz"
      "https://ftp.gnu.org/gnu/ncurses/ncurses-${version}.tar.gz"
    ];
    inherit sha256;
  };

  inherit patches;

  postPatch = ''
    # The bundled platform scripts predate x86_64 and misidentify GNU ld.
    cp ${gnu-config}/config.guess ${gnu-config}/config.sub .
    chmod +w config.guess config.sub
    # GCC 10+ is not GCC 1.x. Preserve the original template blacklist.
    sed -i 's/1\*|2\./1.*|2./g' configure
    # This generator requires each expanded declaration on one line.
    for generator in ncurses/MKlib_gen.sh ncurses/base/MKlib_gen.sh; do
      if test -f "$generator"; then
        sed -i 's/preprocessor="$1 /preprocessor="$1 -P /' "$generator"
      fi
    done
    sed -i 's|SRC_SUBDIRS="$SRC_SUBDIRS misc test"|SRC_SUBDIRS="$SRC_SUBDIRS misc"|' configure
  '';

  preConfigure =
    lib.optionalString (cStandard != null) ''
      export CFLAGS="''${CFLAGS:--O2} -std=${cStandard}"
    ''
    + lib.optionalString (cxxStandard != null) ''
      export CXXFLAGS="''${CXXFLAGS:--O2} -std=${cxxStandard}"
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
    tvp.deps = {
      inherit gnu-config;
    };
    tvp.cc = stdenv.cc;

    tvp.features = {
      widec = true;
      inherit libName cStandard cxxStandard;
      constUserData = cxxBinding && lib.versionAtLeast version "5.3";
      pkgConfig = false;
      # 4.2 ships a c++ demo, not a binding library; libncurses++ arrives at 5.0.
      cxx = cxxBinding && lib.versionAtLeast version "5.0";
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})
