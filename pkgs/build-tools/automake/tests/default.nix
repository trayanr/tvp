{
  pkgs,
  tvpLib,
  package,
}:
let
  project = fixtures: bootstrap: {
    script = ''
      mkdir project
      cd project
      cp -R ${fixtures}/. .
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
      project = project ./fixtures/project ''
        aclocal >&2
        autoconf >&2
        automake --add-missing >&2
        autoreconf >&2
      '';
    }
    // pkgs.lib.optionalAttrs (package.tvp.headerMacro == "AC_CONFIG_HEADERS") {
      headers = project ./fixtures/headers ''
        aclocal >&2
        autoheader >&2
        autoconf >&2
        automake --add-missing >&2
      '';
    }
    // pkgs.lib.optionalAttrs (package.tvp.headerMacro == "AM_CONFIG_HEADER") {
      legacy-headers = project ./fixtures/legacy-headers ''
        aclocal >&2
        autoheader >&2
        autoconf >&2
        automake --add-missing >&2
      '';
    };
}
