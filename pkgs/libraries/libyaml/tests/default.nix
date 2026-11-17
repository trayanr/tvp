# One installed event/document suite for every LibYAML release.
{
  package,
  lib,
  context,
}:
let
  libyaml = package;
  features = package.tvp.features;
  pkgConfig = package.tvp.declaredTestDependencies.pkgConfig;
  tools = package.specification.base.tools // {
    binutils = package.specification.base.compiler.bintools;
  };
in
(context.mkSuite {
  inherit package;
  tools = [
    tools.binutils
    tools.grep
  ];
  libraries = [ package ];
  tests =
    {
      static = {
        script = ''
          cc ${./fixtures/parse.c} ${package}/lib/libyaml.a -o parse
          ./parse
        '';
        expected = "north star name tvp";
      };
      invalid-input = {
        script = ''
          cc ${./fixtures/invalid-event.c} -lyaml -o invalid
          ./invalid
        '';
        expected = "invalid-rejected";
      };
      version = {
        script = ''
          cc ${./fixtures/version.c} -lyaml -o version
          ./version
        '';
        expected = libyaml.version;
        tools = [ ];
      };

      parse = {
        script = ''
          cc ${./fixtures/parse.c} -lyaml -o parse
          ./parse
        '';
        expected = "north star name tvp";
        tools = [ ];
      };

      emit = {
        script = ''
          cc ${./fixtures/emit.c} -lyaml -o emit
          ./emit
        '';
        expected = "tvp";
        tools = [ ];
      };
    }

    // lib.optionalAttrs (features.document or false) {
      invalid-document = {
        script = ''
          cc ${./fixtures/invalid.c} -lyaml -o invalid
          ./invalid
        '';
        expected = "invalid-rejected";
      };
      # The loader API, which builds a node tree rather than a stream of events.
      document = {
        script = ''
          cc ${./fixtures/document.c} -lyaml -o document
          ./document
        '';
        expected = "tvp";
        tools = [ ];
      };
    }

    // lib.optionalAttrs (features.pkgConfig or false) {
      pkg-config = {
        script = ''
          export PKG_CONFIG_LIBDIR=${libyaml}/lib/pkgconfig:${libyaml}/share/pkgconfig
          pkg-config --modversion yaml-0.1
        '';
        expected = libyaml.version;
        tools = [ pkgConfig ];
      };
    };
})
// import ../../gdbm/contracts.nix { inherit package lib context; }
// lib.optionalAttrs package.specification.upstreamCheck.enabled {
  upstream = import ./upstream.nix { inherit package lib context; };
}
