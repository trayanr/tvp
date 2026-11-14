{
  package,
  lib,
  context,
}:
let
  tools = package.specification.base.standardTools;
  consumerStandard = package.tvp.features.consumerCStandard or null;
  configureEnv =
    lib.optionalString (consumerStandard != null)
      "CFLAGS=${lib.escapeShellArg ("-std=" + consumerStandard)} ";
in
context.mkSuite {
  inherit package;
  tools = [
    package.tvp.deps.autoconf
    package.tvp.deps.automake
    package.tvp.deps.m4
    package.tvp.deps.file
    tools.gnumake
    tools.sed
    tools.grep
    tools.gawk
  ];
  libraries = [ package ];
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
    // lib.optionalAttrs (package.tvp.features.nextVersion or false) {
      next-version = {
        script = ''env -i PATH=/no-tools ${package}/bin/libtool-next-version --version'';
        expected = lib.removeSuffix "\n" ''
          libtool-next-version (GNU libtool) ${package.version}
          Copyright (C) 2026 Free Software Foundation, Inc.
          License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.
          This is free software: you are free to change and redistribute it.
          There is NO WARRANTY, to the extent permitted by law.

          Written by Bruno Haible.
        '';
      };
    }
    // lib.optionalAttrs package.tvp.features.acLibtool {
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
          ${configureEnv}../configure --target=${package.specification.base.platform.config} --prefix="$PWD/install" >&2
          make -j"$NIX_BUILD_CORES" >&2
          make install >&2
          readelf -d ./install/bin/answer | grep -Fq 'libanswer.so.1'
          ./install/bin/answer
          ./libtool ${lib.optionalString package.tvp.features.cxxDependencyTracking "--tag=CC "}--mode=link "$CC" -static ${./fixtures/static-main.c} libanswer.la -o static-answer >&2
          if readelf -d static-answer | grep -q 'libanswer.so'; then exit 1; fi
          ./static-answer
        '';
        expected = "42\n42";
      };
    }
    // lib.optionalAttrs (!package.tvp.features.acLibtool) {
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
          ${configureEnv}../configure --target=${package.specification.base.platform.config} --prefix="$PWD/install" >&2
          make -j"$NIX_BUILD_CORES" >&2
          make install >&2
          readelf -d ./install/bin/answer | grep -Fq 'libanswer.so.1'
          ./install/bin/answer
          "$CC" -c ${./fixtures/static-main.c} -o static-main.o
          ./libtool ${lib.optionalString package.tvp.features.cxxDependencyTracking "--tag=CC "}--mode=link "$CC" -static static-main.o libanswer.la -o static-answer >&2
          if readelf -d static-answer | grep -q 'libanswer.so'; then exit 1; fi
          ./static-answer
        '';
        expected = "42\n42";
      };
    }
    // lib.optionalAttrs package.tvp.features.ltdl {
      ltdl = {
        script = ''
          "$CC" -fPIC -shared ${./fixtures/plugin.c} -o plugin.so
          "$CC" ${./fixtures/loader.c} -lltdl -o loader
          ./loader "$PWD/plugin.so"
        '';
        expected = "42";
      };
    }
    // lib.optionalAttrs package.tvp.features.ltInit {
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
          ${configureEnv}../configure --prefix="$PWD/install" >&2
          make -j"$NIX_BUILD_CORES" >&2
          make install >&2
          readelf -d ./install/bin/answer | grep -Fq 'libanswer.so.1'
          readelf -d ./install/bin/answer | grep -Fq 'libcppanswer.so.1'
          ./install/bin/answer
          ./libtool ${lib.optionalString package.tvp.features.cxxDependencyTracking "--tag=CC "}--mode=link "$CC" -static ${./fixtures/static-main.c} libanswer.la -o static-answer >&2
          if readelf -d static-answer | grep -q 'libanswer.so'; then exit 1; fi
          ./static-answer
        '';
        expected = "42\n42";
      };
    }
    // lib.optionalAttrs (!package.tvp.features.ltInit && package.tvp.features.cxxDependencyTracking) {
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
          ${configureEnv}../configure --prefix="$PWD/install" >&2
          make -j"$NIX_BUILD_CORES" >&2
          make install >&2
          readelf -d ./install/bin/answer | grep -Fq 'libanswer.so.1'
          readelf -d ./install/bin/answer | grep -Fq 'libcppanswer.so.1'
          ./install/bin/answer
          ./libtool ${lib.optionalString package.tvp.features.cxxDependencyTracking "--tag=CC "}--mode=link "$CC" -static ${./fixtures/static-main.c} libanswer.la -o static-answer >&2
          if readelf -d static-answer | grep -q 'libanswer.so'; then exit 1; fi
          ./static-answer
        '';
        expected = "42\n42";
      };
    };
}
// (
  if package.tvp.historicalAutotools or false then
    import ../../historical-autotools-tests.nix { inherit package lib context; }
  else
    (
      { }
      // (import ./ordinary-controls.nix { inherit package lib context; })

      // (import ../../ordinary-autotools-split-tests.nix { inherit package lib context; })
    )
)

// lib.optionalAttrs package.specification.doCheck {
  upstream = import ../../autotools-upstream.nix { inherit package lib context; };
}
