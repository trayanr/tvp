# Serves 4.0 through 4.2a. The default target is `static` and `install`
# never builds the shared library, so both have to be asked for by name.
{
  lib,
  stdenv,
  fetchurl,

  ncurses,
  automake,

  version,
  sha256,
  cStandard ? null,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (
  finalAttrs:
  {
    pname = "readline";
    inherit version;

    src = fetchurl {
      urls = [
        "https://mirrors.kernel.org/gnu/readline/readline-${version}.tar.gz"
        "https://ftp.gnu.org/gnu/readline/readline-${version}.tar.gz"
      ];
      inherit sha256;
    };

    buildInputs = [ ncurses ];

    # These platform scripts predate x86_64. Some configure generations ignore
    # that failure and silently disable shared libraries instead of stopping.
    postPatch = ''
      cp ${automake}/share/automake-${automake.version}/config.{guess,sub} support/
    '';

    # Without --with-curses, configure links termcap and the resulting library
    # cannot resolve terminal capabilities against a terminfo database.
    # --with-curses alone makes the *static* library work while leaving
    # libreadline.so with undefined tputs/tgetent/tgoto: support/shobj-conf does
    # not put curses into SHLIB_LIBS on Linux. The build still succeeds, so this
    # has to be stated rather than detected.
    makeFlags = [ "SHLIB_LIBS=-lncursesw" ];

    configureFlags = [ "--with-curses" ];

    installTargets = [
      "install"
      "install-shared"
    ];

    meta = {
      description = "Library for interactive line editing";
      homepage = "https://tiswww.case.edu/php/chet/readline/rltop.html";
      license = lib.licenses.gpl3Plus;
      platforms = lib.platforms.unix;
    };

    passthru = {
      tvp.cc = stdenv.cc;
      inherit version;
      tvp.features = {
        shared = true;
        history = true;
      };

      tvp.deps = {
        inherit ncurses automake;
      };

      tests = mkTests finalAttrs.finalPackage;
    };
  }
  // lib.optionalAttrs (cStandard != null) {
    env.NIX_CFLAGS_COMPILE = "-std=${cStandard}";
    # Old upstream make ignores failed shared/install-shared targets.
    postInstall = ''
      test -s "$out/lib/libreadline.so"
      test -s "$out/lib/libhistory.so"
    '';
  }
)
