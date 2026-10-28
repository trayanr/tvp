{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''libtool --version | head -1 | awk '{print $NF}' '';
      expected = package.version;
    };
    libtoolize = {
      script = ''libtoolize --version | head -1 | awk '{print $NF}' '';
      expected = package.version;
    };
    project = {
      script = ''
        cp ${./fixtures/configure.ac} configure.ac
        cp ${./fixtures/Makefile.am} Makefile.am
        cp ${./fixtures/answer.c} answer.c
        cp ${./fixtures/cppanswer.cc} cppanswer.cc
        cp ${./fixtures/main.c} main.c
        autoreconf --install --force >&2
        mkdir build
        cd build
        ../configure --prefix="$PWD/install" >&2
        make -j"$NIX_BUILD_CORES" >&2
        make install >&2
        readelf -d ./install/bin/answer | grep -Fq 'libanswer.so.1'
        readelf -d ./install/bin/answer | grep -Fq 'libcppanswer.so.1'
        ./install/bin/answer
        ./libtool --mode=link cc -static ${./fixtures/static-main.c} libanswer.la -o static-answer >&2
        if readelf -d static-answer | grep -q 'libanswer.so'; then exit 1; fi
        ./static-answer
      '';
      expected = "42\n42";
      extraInputs = [ package.tvp.cc ];
    };
    ltdl = {
      script = ''
        cc -fPIC -shared ${./fixtures/plugin.c} -o plugin.so
        cc ${./fixtures/loader.c} -lltdl -o loader
        ./loader "$PWD/plugin.so"
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
  };
}
