# One suite, shared by every tcl version. Never fork it per builder: a test that
# exists only for newer versions cannot detect drift in an older one. Guards
# select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  package,
}:

let
  tcl = package;
  pkg-config = package.tvp.deps.pkgConfig;
  deps = tcl.passthru.tvp.deps // {
    inherit (tcl.runtime) zlib libgcc;
  };
  features = tcl.passthru.tvp.features or { };
in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [ package.specification.tools.binutils ];
  libraries = [ package ];

  tests =
    {
      version = {
        script = ''
          tclsh ${./fixtures/version.tcl}
        '';
        expected = tcl.passthru.tvp.reportedVersion or tcl.version;
      };

      # The interpreter itself: control flow, arithmetic, string and list.
      eval = {
        script = ''
          tclsh ${./fixtures/eval.tcl}
        '';
        expected = "42 tvp 3";
      };

      regexp = {
        script = ''
          tclsh ${./fixtures/regexp.tcl}
        '';
        expected = "tvp";
      };

      # sqlite and every other consumer invoke `tclsh`, not `tclsh9.0`.
      tclsh-on-path = {
        script = ''
          command -v tclsh > /dev/null && printf found
        '';
        expected = "found";
      };
    }

    // pkgs.lib.optionalAttrs (features.are or true) {
      # The advanced regexp engine, which replaced the 8.0 one at 8.1.
      regexp-are = {
        script = ''
          tclsh ${./fixtures/regexp-are.tcl}
        '';
        expected = "tvp";
      };
    }

    // pkgs.lib.optionalAttrs (features.pkgConfig or true) {
      pkg-config = {
        script = ''
          export PKG_CONFIG_LIBDIR=${tcl}/lib/pkgconfig:${tcl}/share/pkgconfig
          pkg-config --modversion tcl
        '';
        expected = tcl.passthru.tvp.pkgConfigVersion or tcl.version;

      };
    }

    // pkgs.lib.optionalAttrs (deps ? zlib) {
      zlib = {
        script = ''
          tclsh ${./fixtures/zlib.tcl}
        '';
        expected = "tvp preserves what other software is built on";
      };

      # configure silently falls back to compat/zlib, so the capability working
      # does not prove the declared dependency reached the artifact.
      zlib-linkage = {
        script = ''
          lib=$(echo ${tcl}/lib/libtcl*.so)
          LD_TRACE_LOADED_OBJECTS=1 ${tcl}/bin/tclsh9.1 | awk '/libz\.so/ { print $3 }' | grep -q "^${deps.zlib.out}/" && printf linked
        '';
        expected = "linked";

      };
    };
}

// import ./native-contract-9.1.nix { inherit package; }
