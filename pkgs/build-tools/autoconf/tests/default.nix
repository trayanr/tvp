# One suite, shared by every autoconf version. Never fork it per builder: a
# test that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
#
# The fixtures are an ordinary configure.ac and a template, so these tests
# exercise the whole pipeline — autoconf generates, the generated configure
# runs, and the substitution lands — rather than only checking a version string.
{
  pkgs,
  tvpLib,
  autoconf,
}:
let
  project = ''
    cp ${./fixtures/configure.ac} configure.ac
    cp ${./fixtures/greeting.txt.in} greeting.txt.in
    chmod +w configure.ac greeting.txt.in
    autoconf
  '';
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = autoconf;

  tests = {
    version = {
      script = ''
        autoconf --version | head -1 | awk '{ print $NF }'
      '';
      expected = autoconf.version;
    };

    generate = {
      script = ''
        ${project}
        ./configure --version | head -1
      '';
      expected = "tvp configure 1.2.3";
    };

    # The generated configure actually running and substituting, which is the
    # only thing a consumer cares about.
    substitute = {
      script = ''
        ${project}
        ./configure --silent
        cat greeting.txt
      '';
      expected = "tvp 1.2.3 preserved";
    };

    # autoheader is a separate program sharing autom4te's machinery, so it
    # fails independently of autoconf when the m4 wiring is wrong.
    autoheader = {
      script = ''
        cp ${./fixtures/configure-header.ac} configure.ac
        autoheader
        grep -c TVP_OK config.h.in
      '';
      expected = "1";
    };
  };
}
