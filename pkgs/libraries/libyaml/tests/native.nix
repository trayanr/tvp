# LibYAML owned regular consumers. The complete legacy shared suite remains in default.nix.
{
  pkgs,
  tvpLib,
  package,
  tvp,
}:
let
  libyaml = package;
  cc = [ ];
  pkg-config = package.tvp.declaredTestDependencies.pkg-config;
  features = libyaml.passthru.tvp.features or { };
in
package.testContext.mkSuite {
  inherit package;
  tools =
    package.specification.environment.tools
    ++ [ package.tvp.cc.bintools ]
    ++ (with (import ../../../../bases/source-gnu { }).tools; [
      grep
      sed
      gawk
      diffutils
    ]);
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
          cc ${./fixtures/invalid.c} -lyaml -o invalid
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
        tools = cc;
      };

      parse = {
        script = ''
          cc ${./fixtures/parse.c} -lyaml -o parse
          ./parse
        '';
        expected = "north star name tvp";
        tools = cc;
      };

      emit = {
        script = ''
          cc ${./fixtures/emit.c} -lyaml -o emit
          ./emit
        '';
        expected = "tvp";
        tools = cc;
      };
    }

    // pkgs.lib.optionalAttrs (features.document or false) {
      # The loader API, which builds a node tree rather than a stream of events.
      document = {
        script = ''
          cc ${./fixtures/document.c} -lyaml -o document
          ./document
        '';
        expected = "tvp";
        tools = cc;
      };
    }

    // pkgs.lib.optionalAttrs (features.pkgConfig or false) {
      pkg-config = {
        script = ''
          export PKG_CONFIG_LIBDIR=${libyaml}/lib/pkgconfig:${libyaml}/share/pkgconfig
          pkg-config --modversion yaml-0.1
        '';
        expected = libyaml.version;
        tools = [ pkg-config ];
      };
    };
}

// (if (package ? specification) && (package.specification ? upstreamPlan) && (package.specification.upstreamCheck.enabled or true) then {
  # Independent native upstream registration.
  upstream = import ../native/upstream.nix { package = package; };
} else { })
