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
  package,
}:
let
  ncurses = package;
  pkg-config = package.tvp.deps.pkgConfig;
  # Compile consumers with the package compiler and its declared dialects.
  cc = ncurses.specification.environment.tools;
  features = ncurses.tvp.features or { };

  # 5.1 renamed the wide build to ncursesw; 4.2 and 5.0 call it ncurses.
  libName = features.libName or "ncursesw";
  hasPc = features.pkgConfig or true;
  suffix = pkgs.lib.removePrefix "ncurses" libName;

  ccFlags =
    if hasPc then
      "$(PKG_CONFIG_LIBDIR=${ncurses}/lib/pkgconfig:${ncurses}/share/pkgconfig pkg-config --cflags --libs ${libName})"
    else
      "-I${ncurses}/include/${libName} -I${ncurses}/include -l${libName}";

  cFlags = pkgs.lib.optionalString (
    (features.cStandard or null) != null
  ) "-std=${features.cStandard}";
  cxxFlags = pkgs.lib.optionalString (
    (features.cxxStandard or null) != null
  ) "-std=${features.cxxStandard}";

  ccInputs = cc ++ pkgs.lib.optional hasPc pkg-config;
in
package.testContext.mkSuite {
  inherit package;
  tools = ccInputs;
  libraries = [ ncurses ];

  tests =
    {
      version = {
        script = ''
          unset COLUMNS LINES TERMINFO TERMINFO_DIRS
          export TERM=xterm TERMINFO=${ncurses}/share/terminfo TERMINFO_DIRS=${ncurses}/share/terminfo
          cc ${cFlags} ${./fixtures/version.c} ${ccFlags} -o version
          ./version
        '';
        expected = ncurses.version;
        tools = ccInputs;
      };

      # setupterm against the installed database, which is the half of ncurses
      # that is data rather than code.
      terminfo = {
        script = ''
          unset COLUMNS LINES TERMINFO TERMINFO_DIRS
          export TERM=xterm TERMINFO=${ncurses}/share/terminfo TERMINFO_DIRS=${ncurses}/share/terminfo
          cc ${cFlags} ${./fixtures/terminfo.c} ${ccFlags} -o terminfo
          ./terminfo
        '';
        expected = "80";
        tools = ccInputs;
      };

      # The shipped tools read the same database through a different path.
      tput = {
        script = ''
          unset COLUMNS LINES TERMINFO TERMINFO_DIRS
          export TERM=xterm TERMINFO=${ncurses}/share/terminfo TERMINFO_DIRS=${ncurses}/share/terminfo
          TERM=xterm tput cols
        '';
        expected = "80";
      };

      # panel is a separate library from the same tree, and a build that loses
      # it still installs and still passes every test above.
      panel = {
        script = ''
          unset COLUMNS LINES TERMINFO TERMINFO_DIRS
          export TERM=xterm TERMINFO=${ncurses}/share/terminfo TERMINFO_DIRS=${ncurses}/share/terminfo
          cc ${cFlags} ${./fixtures/panel.c} -lpanel${suffix} ${ccFlags} -o panel
          ./panel
        '';
        expected = "panel-ok";
        tools = ccInputs;
      };
    }

    // pkgs.lib.optionalAttrs hasPc {
      # The .pc carries a patch date (6.6.20251230); the release version is the
      # first two components, so only those are compared.
      pkg-config = {
        script = ''
          unset COLUMNS LINES TERMINFO TERMINFO_DIRS
          export TERM=xterm TERMINFO=${ncurses}/share/terminfo TERMINFO_DIRS=${ncurses}/share/terminfo
          export PKG_CONFIG_LIBDIR=${ncurses}/lib/pkgconfig:${ncurses}/share/pkgconfig
          pkg-config --modversion ${libName} | cut -d. -f1,2
        '';
        expected = ncurses.version;
        tools = [ pkg-config ];
      };
    }

    // pkgs.lib.optionalAttrs (features.constUserData or false) {
      cxx-user-pointer = {
        script = ''
          unset COLUMNS LINES TERMINFO TERMINFO_DIRS
          export TERM=xterm TERMINFO=${ncurses}/share/terminfo TERMINFO_DIRS=${ncurses}/share/terminfo
          c++ ${cxxFlags} ${./fixtures/cxx-user-pointer.cc} -lncurses++${suffix} -lform${suffix} -lmenu${suffix} -lpanel${suffix} ${ccFlags} -o cxx-user-pointer
          TERM=xterm ./cxx-user-pointer
        '';
        expected = "user-pointer-ok";
        tools = ccInputs;
      };
    }

    # Keep the binding library and its consumer dialect covered separately.
    // pkgs.lib.optionalAttrs (features.cxx or false) {
      cxx = {
        script = ''
          unset COLUMNS LINES TERMINFO TERMINFO_DIRS
          export TERM=xterm TERMINFO=${ncurses}/share/terminfo TERMINFO_DIRS=${ncurses}/share/terminfo
          c++ ${cxxFlags} ${./fixtures/cxx.cc} -lncurses++${suffix} ${ccFlags} -o cxx
          ./cxx
        '';
        expected = "cxx-ok";
        tools = ccInputs;
      };
    };
}
