{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''automake --version | head -1 | awk '{print $NF}' '';
      expected = package.version;
    };
    aclocal = {
      script = ''aclocal --version | head -1 | awk '{print $NF}' '';
      expected = package.version;
    };
    project = {
      script = ''
        cp ${./fixtures/configure.ac} configure.ac
        cp ${./fixtures/Makefile.am} Makefile.am
        cp ${./fixtures/main.c} main.c
        autoreconf --install --force >&2
        mkdir build
        cd build
        ../configure --prefix="$PWD/install" >&2
        make -j"$NIX_BUILD_CORES" >&2
        make install >&2
        ./install/bin/answer
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
  };
}
