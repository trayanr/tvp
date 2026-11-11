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
    compiled-discovery = {
      tools = [ package.tvp.deps.binutils ];
      script = ''
        mkdir include lib pc
        printf 'int private_answer(void) { return 42; }\n' > private.c
        printf 'int private_answer(void); int answer(void) { return private_answer(); }\n' > public.c
        printf '#ifdef __cplusplus\nextern "C" {\n#endif\nint answer(void);\n#ifdef __cplusplus\n}\n#endif\n' > include/answer.h
        printf '#include <answer.h>\nint main(void) { return answer() != 42; }\n' > main.c
        "$CC" -fPIC -c private.c -o private.o
        "$CC" -fPIC -c public.c -o public.o
        ar crs lib/libprivate.a private.o
        ar crs lib/libpublic.a public.o
        "$CC" -shared private.o -o lib/libprivate.so
        "$CC" -shared public.o -L"$PWD/lib" -lprivate -Wl,-rpath,"$PWD/lib" -o lib/libpublic.so
        cat > pc/public.pc <<EOF
        Name: public
        Description: real C and C++ fixture
        Version: 1
        Cflags: -I$PWD/include
        Libs: -L$PWD/lib -lpublic
        Requires.private: private
        EOF
        cat > pc/private.pc <<EOF
        Name: private
        Description: private link closure
        Version: 1
        Libs: -lprivate
        EOF
        export PKG_CONFIG_LIBDIR="$PWD/pc" PKG_CONFIG_PATH=
        "$CC" $(pkg-config --cflags public) main.c $(pkg-config --libs public) -Wl,-rpath,"$PWD/lib" -Wl,-rpath-link,"$PWD/lib" -o shared
        "$CXX" -x c++ $(pkg-config --cflags public) main.c -Wl,-Bstatic $(pkg-config --static --libs public) -Wl,-Bdynamic -o static
        env -i ./shared
        env -i ./static
        printf linked
      '';
      expected = "linked";
    };
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
        test "$(pkg-config --libs public | sed 's/ *$//')" = '-lpublic'
        test "$(pkg-config --static --libs public | sed 's/ *$//')" = '-lpublic -lm -lprivate'
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
