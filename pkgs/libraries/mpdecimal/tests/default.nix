{
  package,
  lib,
  context,
}:

let
  features = package.tvp.features;
  pkgConfig = package.tvp.declaredTestDependencies.pkgConfig;
in
context.mkSuite {
  inherit package;
  tools = [ pkgConfig ];
  libraries = [ package ];
  tests = {
    version = {
      script = "cc ${./fixtures/version.c} -lmpdec -o version; ./version";
      expected = package.version;

    };
    c = {
      script = "cc ${./fixtures/arithmetic.c} -lmpdec -o arithmetic; ./arithmetic";
      expected = "0.3";

    };
    pkg-config = {
      script = "export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig; pkg-config --modversion libmpdec";
      expected = package.version;
    };
  }
  // lib.optionalAttrs features.cxx {
    cxx = {
      script = "c++ ${./fixtures/arithmetic.cc} -lmpdec++ -lmpdec -o arithmetic; ./arithmetic";
      expected = "0.3";

    };
  }
  // lib.optionalAttrs features.static {
    static-c = {
      script = "cc ${./fixtures/arithmetic.c} ${package}/lib/libmpdec.a -lm -o arithmetic; ./arithmetic";
      expected = "0.3";
    };
  }
  // lib.optionalAttrs (features.static && features.cxx) {
    static-cxx = {
      script = "c++ ${./fixtures/arithmetic.cc} ${package}/lib/libmpdec++.a ${package}/lib/libmpdec.a -lm -o arithmetic; ./arithmetic";
      expected = "0.3";
    };
  };
}

// import ../../ffi-decimal-contracts.nix { inherit package lib context; }

// (import ./abi.nix { inherit package lib context; })
// lib.optionalAttrs (package.specification.upstreamCheck.enabled or true) {
  upstream = context.mkUpstream { inherit package; };
}
