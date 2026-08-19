# One suite, shared by every ncurses version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
#
# The widec build installs its headers under include/ncursesw, so the compile
# tests take their flags from pkg-config where it exists — which is how
# consumers find them — and from the declared library name where it does not.
{
  pkgs,
  tvpLib,
  ncurses,
}:
let
  # The compiler the package was built with, not the default one: a library
  # built on gcc 4.9 ships headers a current C++ dialect rejects.
  cc = [ ncurses.passthru.tvp.cc ];
  features = ncurses.passthru.tvp.features or { };

  # 5.1 renamed the wide build to ncursesw; 4.2 and 5.0 call it ncurses.
  libName = features.libName or "ncursesw";
  hasPc = features.pkgConfig or true;
  suffix = pkgs.lib.removePrefix "ncurses" libName;

  ccFlags =
    if hasPc then
      "$(pkg-config --cflags --libs ${libName})"
    else
      "-I${ncurses}/include/${libName} -I${ncurses}/include -l${libName}";

  ccInputs = cc ++ pkgs.lib.optional hasPc pkgs.pkg-config;
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = ncurses;

  tests =
    {
      version = {
        script = ''
          cc ${./fixtures/version.c} ${ccFlags} -o version
          ./version
        '';
        expected = ncurses.version;
        extraInputs = ccInputs;
      };

      # setupterm against the installed database, which is the half of ncurses
      # that is data rather than code.
      terminfo = {
        script = ''
          cc ${./fixtures/terminfo.c} ${ccFlags} -o terminfo
          ./terminfo
        '';
        expected = "80";
        extraInputs = ccInputs;
      };

      # The shipped tools read the same database through a different path.
      tput = {
        script = ''
          TERM=xterm tput cols
        '';
        expected = "80";
      };

      # panel is a separate library from the same tree, and a build that loses
      # it still installs and still passes every test above.
      panel = {
        script = ''
          cc ${./fixtures/panel.c} -lpanel${suffix} ${ccFlags} -o panel
          ./panel
        '';
        expected = "panel-ok";
        extraInputs = ccInputs;
      };
    }

    // pkgs.lib.optionalAttrs hasPc {
      # The .pc carries a patch date (6.6.20251230); the release version is the
      # first two components, so only those are compared.
      pkg-config = {
        script = ''
          pkg-config --modversion ${libName} | cut -d. -f1,2
        '';
        expected = ncurses.version;
        extraInputs = [ pkgs.pkg-config ];
      };
    }

    # The C++ binding is its own library and its own dialect problem: every
    # release from 5.0 to 6.0 needed an older compiler to build it at all.
    // pkgs.lib.optionalAttrs (features.cxx or false) {
      cxx = {
        script = ''
          c++ ${./fixtures/cxx.cc} -lncurses++${suffix} ${ccFlags} -o cxx
          ./cxx
        '';
        expected = "cxx-ok";
        extraInputs = ccInputs;
      };
    };
}
