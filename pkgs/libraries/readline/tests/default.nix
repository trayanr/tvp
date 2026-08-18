# One suite, shared by every readline version. Never fork it per builder: a
# test that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
#
# readline installs no useful executable, so every test compiles against the
# headers and links the library — which is how every consumer uses it.
{
  pkgs,
  tvpLib,
  readline,
}:
let
  inherit (readline.tvp) features;

  # Linking -lncursesw by name is what makes these work against a static-only
  # readline, so ncurses has to be present at link time rather than arriving
  # through libreadline.so's own DT_NEEDED.
  cc = [
    pkgs.stdenv.cc
    readline.tvp.deps.ncurses
  ];
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = readline;

  tests =
    {
      version = {
        script = ''
          cc ${./fixtures/version.c} -lreadline -lncursesw -o version
          ./version
        '';
        # A three-part tarball is a patch rollup and reports its major.minor:
        # 8.2.13 carries AC_INIT(readline, 8.2). A letter suffix is not a rollup —
        # 4.2a is its own release and reports 4.2a.
        expected =
          if builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" readline.version != null then
            pkgs.lib.versions.majorMinor readline.version
          else
            readline.version;
        extraInputs = cc;
      };
    }

    # 2.0 and 2.1 compile the history functions into libreadline.a and ship no
    # separate archive, so there is nothing for -lhistory to find.
    // pkgs.lib.optionalAttrs (features.history or true) {
      history = {
        script = ''
          cc ${./fixtures/history.c} -lreadline -lhistory -lncursesw -o history
          ./history
        '';
        expected = "2 tvp";
        extraInputs = cc;
      };
    }

    # A static-only readline has no .so for ldd to inspect, and linking the
    # archive says nothing about what the library itself carries.
    // pkgs.lib.optionalAttrs (features.shared or true) {
      # Proves the declared ncurses is actually linked: without a terminfo-backed
      # curses, readline cannot resolve a terminal's capabilities.
      terminal = {
        script = ''
          cc ${./fixtures/version.c} -lreadline -o version
          ldd ./version | grep -c 'libncursesw\|libtinfo'
        '';
        expected = "1";
        extraInputs = cc;
      };
    };
}
