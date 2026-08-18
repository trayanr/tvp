# One suite, shared by every ncurses version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
#
# The widec build installs its headers under include/ncursesw, so the compile
# tests take their flags from pkg-config — which is how consumers find them.
{
  pkgs,
  tvpLib,
  ncurses,
}:
let
  cc = [
    pkgs.stdenv.cc
    pkgs.pkg-config
  ];
  features = ncurses.passthru.tvp.features or { };
  lib = if (features.widec or false) then "ncursesw" else "ncurses";
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = ncurses;

  tests = {
    version = {
      script = ''
        cc ${./fixtures/version.c} $(pkg-config --cflags --libs ${lib}) -o version
        ./version
      '';
      expected = ncurses.version;
      extraInputs = cc;
    };

    # setupterm against the installed database, which is the half of ncurses
    # that is data rather than code.
    terminfo = {
      script = ''
        cc ${./fixtures/terminfo.c} $(pkg-config --cflags --libs ${lib}) -o terminfo
        ./terminfo
      '';
      expected = "80";
      extraInputs = cc;
    };

    # The shipped tools read the same database through a different path.
    tput = {
      script = ''
        TERM=xterm tput cols
      '';
      expected = "80";
    };

    # The .pc carries a patch date (6.6.20251230); the release version is the
    # first two components, so only those are compared.
    pkg-config = {
      script = ''
        pkg-config --modversion ${lib} | cut -d. -f1,2
      '';
      expected = ncurses.version;
      extraInputs = [ pkgs.pkg-config ];
    };
  };
}
