# Serves 8.0 onwards.
{
  lib,
  stdenv,
  fetchurl,

  ncurses,

  version,
  sha256,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
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

  meta = {
    description = "Library for interactive line editing";
    homepage = "https://tiswww.case.edu/php/chet/readline/rltop.html";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };

  passthru = {
    inherit version;
    tvp.features = {
      shared = true;
      history = true;
    };

    tvp.deps = {
      inherit ncurses;
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})
