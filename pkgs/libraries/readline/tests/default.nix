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
  cc = [ pkgs.stdenv.cc ];
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = readline;

  tests = {
    # Three-component readline tarballs are patch rollups, not versions:
    # readline-8.2.13 carries AC_INIT(readline, 8.2) and reports 8.2 at runtime.
    # Comparing major.minor is therefore the only thing that holds for both.
    version = {
      script = ''
        cc ${./fixtures/version.c} -lreadline -o version
        ./version
      '';
      expected = pkgs.lib.versions.majorMinor readline.version;
      extraInputs = cc;
    };

    history = {
      script = ''
        cc ${./fixtures/history.c} -lreadline -lhistory -o history
        ./history
      '';
      expected = "2 tvp";
      extraInputs = cc;
    };

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
