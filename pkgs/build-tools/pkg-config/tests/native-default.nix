# One suite, shared by every pkg-config version. Never fork it per builder: a
# test that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
#
# The fixtures are ordinary .pc files, so these tests exercise pkg-config the
# way a configure script does rather than the way its own test suite does.
{
  pkgs,
  tvpLib,
  package,
  tvp,
}:
let
  pkgConfig = package;
  # Copied rather than pointed at, so PKG_CONFIG_PATH is a directory containing
  # only these two files.
  fixtures = ''
    mkdir pc
    cp ${./fixtures/tvp.pc} pc/tvp.pc
    cp ${./fixtures/tvpdep.pc} pc/tvpdep.pc
    export PKG_CONFIG_PATH=$PWD/pc
  '';
in
package.testContext.mkSuite {
  tools = [ package.tvp.deps.sed ];
  inherit package;

  tests = {
    static = {
      script = ''
        mkdir pc
        cat > pc/public.pc <<EOF
        Name: public
        Description: public fixture
        Version: 2
        Libs: -lpublic
        Libs.private: -lm
        Requires.private: private >= 1
        EOF
        cat > pc/private.pc <<EOF
        Name: private
        Description: private fixture
        Version: 1
        Libs: -lprivate
        EOF
        export PKG_CONFIG_LIBDIR="$PWD/pc"
        test "$(pkg-config --libs public)" = '-lpublic'
        test "$(pkg-config --static --libs public)" = '-lpublic -lm -lprivate'
        if pkg-config --exists 'public >= 3' 2> diagnostic; then exit 1; fi
        if pkg-config --print-errors --exists missing > diagnostic 2>&1; then exit 1; fi
        ${package.tvp.deps.python}/bin/python3 -c 'assert "missing" in open("diagnostic").read(); print("static-private")'
      '';
      expected = "static-private";
    };
    precedence = {
      script = ''
        mkdir provider user
        printf 'Name: choice\nDescription: provider\nVersion: 1\n' > provider/choice.pc
        printf 'Name: choice\nDescription: user\nVersion: 2\n' > user/choice.pc
        export PKG_CONFIG_LIBDIR="$PWD/provider" PKG_CONFIG_PATH="$PWD/user"
        test "$(pkg-config --modversion choice)" = 2
        export PKG_CONFIG_PATH=
        test "$(pkg-config --modversion choice)" = 1
        export PKG_CONFIG_LIBDIR=
        if pkg-config --exists choice; then exit 1; fi
        printf isolated
      '';
      expected = "isolated";
    };
    public-development = {
      libraries = [ tvp.packages.mpfr ];
      script = ''
        test "$($PKG_CONFIG --modversion mpfr)" = '${tvp.packages.mpfr.version}'
        "$CC" $($PKG_CONFIG --cflags mpfr) ${../../../libraries/mpfr/tests/fixtures/arithmetic.c} $($PKG_CONFIG --libs mpfr) -o arithmetic
        ./arithmetic
      '';
      expected = "12";
    };
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

// {
  constructor = import ../../native-frontend-contract.nix { inherit pkgs tvp package; };
}
