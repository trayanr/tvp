{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests =
    {
      version = {
        script = ''libtool --version | awk 'NR == 1 {for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+([.][0-9]+)+$/) {print $i; break}}' '';
        expected = package.version;
      };
      libtoolize = {
        script = ''libtoolize --version | awk 'NR == 1 {for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+([.][0-9]+)+$/) {print $i; break}}' '';
        expected = package.version;
      };
    }
    // pkgs.lib.optionalAttrs package.tvp.features.acLibtool {
      core-project = {
        script = ''
          mkdir -p m4
          cp ${./fixtures/configure-core.ac} configure.in
          cp ${./fixtures/Makefile-core.am} Makefile.am
          cp ${./fixtures/answer.c} answer.c
          cp ${./fixtures/core-main.c} main.c
          autoreconf --install --force >&2
          mkdir build
          cd build
          ../configure --target=${pkgs.stdenv.hostPlatform.config} --prefix="$PWD/install" >&2
          make -j"$NIX_BUILD_CORES" >&2
          make install >&2
          readelf -d ./install/bin/answer | grep -Fq 'libanswer.so.1'
          ./install/bin/answer
          ./libtool --mode=link cc -static ${./fixtures/static-main.c} libanswer.la -o static-answer >&2
          if readelf -d static-answer | grep -q 'libanswer.so'; then exit 1; fi
          ./static-answer
        '';
        expected = "42\n42";
        extraInputs = [ package.tvp.cc ];
      };
    }
    // pkgs.lib.optionalAttrs (!package.tvp.features.acLibtool) {
      core-am-project = {
        script = ''
          mkdir -p m4
          cp ${./fixtures/configure-am.ac} configure.in
          cp ${./fixtures/Makefile-core.am} Makefile.am
          cp ${./fixtures/answer.c} answer.c
          cp ${./fixtures/core-main.c} main.c
          aclocal -I ${package}/share/aclocal >&2
          libtoolize --force --copy >&2
          autoconf >&2
          automake --add-missing --foreign >&2
          mkdir build
          cd build
          ../configure --target=${pkgs.stdenv.hostPlatform.config} --prefix="$PWD/install" >&2
          make -j"$NIX_BUILD_CORES" >&2
          make install >&2
          readelf -d ./install/bin/answer | grep -Fq 'libanswer.so.1'
          ./install/bin/answer
          cc -c ${./fixtures/static-main.c} -o static-main.o
          ./libtool --mode=link cc -static static-main.o libanswer.la -o static-answer >&2
          if readelf -d static-answer | grep -q 'libanswer.so'; then exit 1; fi
          ./static-answer
        '';
        expected = "42\n42";
        extraInputs = [ package.tvp.cc ];
      };
    }
    // pkgs.lib.optionalAttrs package.tvp.features.ltdl {
      ltdl = {
        script = ''
          cc -fPIC -shared ${./fixtures/plugin.c} -o plugin.so
          cc ${./fixtures/loader.c} -lltdl -o loader
          ./loader "$PWD/plugin.so"
        '';
        expected = "42";
        extraInputs = [ package.tvp.cc ];
      };
    }
    // pkgs.lib.optionalAttrs package.tvp.features.ltInit {
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
    }
    //
      pkgs.lib.optionalAttrs (!package.tvp.features.ltInit && package.tvp.features.cxxDependencyTracking)
        {
          project-legacy = {
            script = ''
              cp ${./fixtures/configure-legacy.ac} configure.ac
              cp ${./fixtures/Makefile.am} Makefile.am
              cp ${./fixtures/answer.c} answer.c
              cp ${./fixtures/cppanswer.cc} cppanswer.cc
              cp ${./fixtures/main.c} main.c
              mkdir -p m4
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
        };
}
