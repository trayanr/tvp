{
  pkgs,
  tvpLib,
  package,
}:
let
  project = files: bootstrap: {
    script = ''
      mkdir project
      cd project
      ${pkgs.lib.concatMapStringsSep "\n" (
        file: ''cp ${file} ${pkgs.lib.escapeShellArg (baseNameOf file)}''
      ) files}
      ${bootstrap}
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
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests =
    {
      version = {
        script = ''automake --version | head -1 | awk '{print $NF}' '';
        expected = package.version;
      };
      aclocal = {
        script = ''aclocal --version | head -1 | awk '{print $NF}' '';
        expected = package.version;
      };
      bootstrap =
        project
          [
            ./fixtures/project/configure.in
            ./fixtures/project/Makefile.am
            ./fixtures/project/main.c
          ]
          ''
            aclocal >&2
            autoconf >&2
            automake --add-missing >&2
            autoreconf >&2
          '';
    }
    // pkgs.lib.optionalAttrs package.tvp.features.automaticCcCo {
      project =
        project
          [
            ./fixtures/autoreconf/configure.ac
            ./fixtures/headers/Makefile.am
            ./fixtures/headers/main.c
          ]
          ''
            autoreconf --install --force >&2
          '';
    }
    // pkgs.lib.optionalAttrs (package.tvp.headerMacro == "AC_CONFIG_HEADERS") {
      headers =
        project
          [
            ./fixtures/headers/configure.in
            ./fixtures/headers/Makefile.am
            ./fixtures/headers/main.c
          ]
          ''
            aclocal >&2
            autoheader >&2
            autoconf >&2
            automake --add-missing >&2
          '';
    }
    // pkgs.lib.optionalAttrs (package.tvp.headerMacro == "AM_CONFIG_HEADER") {
      legacy-headers =
        project
          [
            ./fixtures/legacy-headers/configure.in
            ./fixtures/legacy-headers/Makefile.am
            ./fixtures/legacy-headers/main.c
            ./fixtures/legacy-headers/acconfig.h
          ]
          ''
            aclocal >&2
            autoheader >&2
            autoconf >&2
            automake --add-missing >&2
          '';
    };
}
