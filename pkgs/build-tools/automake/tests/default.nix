{
  pkgs,
  tvpLib,
  package,
}:
let
  # 1.0 ships macros as a single file; the aclocal command and AM_INIT_AUTOMAKE
  # arrived later. Exercise its documented interface with the same C projects.
  hasAclocal = package.tvp.features.aclocal or true;
  collectMacros =
    if hasAclocal then "aclocal >&2" else ''cp ${package}/share/automake/aclocal.m4 aclocal.m4'';
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
      bootstrap =
        project
          [
            (if hasAclocal then ./fixtures/project/configure.in else ./fixtures/project-1.0/configure.in)
            ./fixtures/project/Makefile.am
            ./fixtures/project/main.c
          ]
          ''
            ${collectMacros}
            autoconf >&2
            automake --add-missing >&2
            ${if hasAclocal then "autoreconf" else "autoreconf --force"} >&2
          '';
    }
    // pkgs.lib.optionalAttrs hasAclocal {
      aclocal = {
        script = ''aclocal --version | head -1 | awk '{print $NF}' '';
        expected = package.version;
      };
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
    }
    // pkgs.lib.optionalAttrs (package.tvp.headerMacro == "AC_CONFIG_HEADER") {
      headers =
        project
          [
            ./fixtures/headers-1.0/configure.in
            ./fixtures/legacy-headers/Makefile.am
            ./fixtures/legacy-headers/main.c
            ./fixtures/legacy-headers/acconfig.h
          ]
          ''
            ${collectMacros}
            touch stamp-h.in
            autoheader >&2
            autoconf >&2
            automake --add-missing >&2
          '';
    };
}
