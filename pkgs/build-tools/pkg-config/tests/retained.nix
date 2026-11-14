# One suite, shared by every pkg-config version. Never fork it per builder: a
# test that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
#
# The fixtures are ordinary .pc files, so these tests exercise pkg-config the
# way a configure script does rather than the way its own test suite does.
{
  pkgs,
  tvpLib,
  pkgConfig,
}:
let
  # Copied rather than pointed at, so PKG_CONFIG_PATH is a directory containing
  # only these two files.
  fixtures = ''
    mkdir pc
    cp ${./fixtures/tvp.pc} pc/tvp.pc
    cp ${./fixtures/tvpdep.pc} pc/tvpdep.pc
    export PKG_CONFIG_PATH=$PWD/pc
  '';
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = pkgConfig;

  tests = {
    version = {
      script = ''
        pkg-config --version
      '';
      expected = pkgConfig.version;
    };

    modversion = {
      script = ''
        ${fixtures}
        pkg-config --modversion tvp
      '';
      expected = "1.2.3";
    };

    # Releases before 0.29 emit a trailing space after the last flag. It is
    # meaningless to every consumer — the output goes straight onto a command
    # line — so the suite compares flags rather than whitespace, for every
    # version alike.
    # Variable expansion inside a .pc file — prefix/libdir/includedir chains are
    # what every real .pc relies on.
    cflags = {
      script = ''
        ${fixtures}
        pkg-config --cflags tvp | sed 's/ *$//'
      '';
      expected = "-I/tvp/include";
    };

    libs = {
      script = ''
        ${fixtures}
        pkg-config --libs tvp | sed 's/ *$//'
      '';
      expected = "-L/tvp/lib -ltvp";
    };

    # Requires: is the whole reason pkg-config exists rather than a grep.
    requires = {
      script = ''
        ${fixtures}
        pkg-config --libs tvpdep | sed 's/ *$//'
      '';
      expected = "-L/tvp/lib -ltvpdep -ltvp";
    };

    # Version comparison drives every configure-time feature check.
    atleast = {
      script = ''
        ${fixtures}
        pkg-config --atleast-version=1.2.0 tvp && echo yes
        pkg-config --atleast-version=9.9.9 tvp || echo no
      '';
      expected = "yes\nno";
    };
  };
}
