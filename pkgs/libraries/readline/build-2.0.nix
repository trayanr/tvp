# Serves 2.2.1 and older. These predate support/shobj-conf: the shared-library
# rule is a SunOS-era `ld -assert pure-text` line that modern binutils rejects,
# and 2.0 has no install-shared target at all. Static libraries only.
{
  lib,
  stdenv,
  fetchurl,

  ncurses,

  version,
  sha256,

  patches ? [ ],

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (
  finalAttrs:
  {
    pname = "readline";
    inherit version;

    src = fetchurl {
      url = "https://ftp.gnu.org/gnu/readline/readline-${version}.tar.gz";
      inherit sha256;
    };

    buildInputs = [ ncurses ];

    # Without --with-curses, configure links termcap and the resulting library
    # cannot resolve terminal capabilities against a terminfo database.
    # --with-curses alone makes the *static* library work while leaving
    # libreadline.so with undefined tputs/tgetent/tgoto: support/shobj-conf does
    # not put curses into SHLIB_LIBS on Linux. The build still succeeds, so this
    # has to be stated rather than detected.
    makeFlags = [ "SHLIB_LIBS=-lncursesw" ];

    configureFlags = [ "--with-curses" ];

    # TVP's ncurses installs its headers under include/ncursesw and ships no
    # setup hook to put them on the search path. 2.0 includes <termcap.h>
    # directly rather than reaching it through curses.h, so the path is named
    # here — the same hidden work a distribution does, made explicit.
    env.NIX_CFLAGS_COMPILE = "-I${lib.getDev ncurses}/include/ncursesw";

    # 2.0's Makefile references $(incdir) four times and defines it nowhere, so
    # its install target tries to mkdir /readline. Later releases use
    # @includedir@ and ignore this.
    installFlags = [ "incdir=${placeholder "out"}/include" ];

    # installdirs uses plain mkdir for include/readline, so its parent has to
    # exist. Not lib: `[ ! -d $lib ] && mkdir $lib` returns 1 when it already
    # exists, and make stops.
    preInstall = ''
      mkdir -p "$out/include"
    '';

    meta = {
      description = "Library for interactive line editing";
      homepage = "https://tiswww.case.edu/php/chet/readline/rltop.html";
      license = lib.licenses.gpl3Plus;
      platforms = lib.platforms.unix;
    };

    passthru = {
      inherit version;
      tvp.features = {
        shared = false;
        # 2.0 and 2.1 build history into libreadline.a; libhistory.a arrives at 2.2.
        history = lib.versionAtLeast version "2.2";
      };

      tvp.deps = {
        inherit ncurses;
      };

      tests = mkTests finalAttrs.finalPackage;
    };
  }
  // lib.optionalAttrs (patches != [ ]) { inherit patches; }
)
