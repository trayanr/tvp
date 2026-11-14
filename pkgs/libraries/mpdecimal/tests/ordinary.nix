{
  pkgs,
  tvpLib,
  tvp,
  package,
}:
let
  features = package.tvp.features;
in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools;
  libraries = [ package ];
  tests =
    {
      version = {
        script = ''cc ${./fixtures/version.c} -lmpdec -o version; ./version'';
        expected = package.version;

      };
      c = {
        script = ''cc ${./fixtures/arithmetic.c} -lmpdec -o arithmetic; ./arithmetic'';
        expected = "0.3";

      };
      pkg-config = {
        script = ''export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig; pkg-config --modversion libmpdec'';
        expected = package.version;
      };
    }
    // pkgs.lib.optionalAttrs features.cxx {
      cxx = {
        script = ''c++ ${./fixtures/arithmetic.cc} -lmpdec++ -lmpdec -o arithmetic; ./arithmetic'';
        expected = "0.3";

      };
    }
    // pkgs.lib.optionalAttrs features.static {
      static-c = {
        script = ''cc ${./fixtures/arithmetic.c} ${package}/lib/libmpdec.a -lm -o arithmetic; ./arithmetic'';
        expected = "0.3";
      };
    }
    // pkgs.lib.optionalAttrs (features.static && features.cxx) {
      static-cxx = {
        script = ''c++ ${./fixtures/arithmetic.cc} ${package}/lib/libmpdec++.a ${package}/lib/libmpdec.a -lm -o arithmetic; ./arithmetic'';
        expected = "0.3";
      };
    };
}

// import ../../libffi/ordinary/contracts.nix { inherit tvp package; }
