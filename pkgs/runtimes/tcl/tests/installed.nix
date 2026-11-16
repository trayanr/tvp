# Shared installed Tcl assertions; guards retain the historical API boundaries.
{
  package,
  lib,
  context,
}:
let
  tcl = package;
  deps = tcl.passthru.tvp.deps or { };
  features = tcl.passthru.tvp.features or { };
  tools = (tcl.specification.base.tools or { }) // {
    binutils = tcl.specification.base.compiler.bintools;
  };
  pkg-config = tcl.specification.testPkgConfig or tcl.tvp.declaredTestDependencies.pkg-config;
  suite =
    args:
    context.mkSuite {
      inherit (args) package;
      tools = tcl.specification.environment.tools ++ [ tools.binutils ];
      libraries = [ tcl ];
      tests = builtins.mapAttrs (
        _: spec:
        builtins.removeAttrs spec [ "extraInputs" ]
        // lib.optionalAttrs (spec ? extraInputs) {
          tools =
            (builtins.filter (p: (p.pname or "") != "pkg-config") tcl.specification.environment.tools)
            ++ [ tools.binutils ]
            ++ spec.extraInputs;
        }
      ) args.tests;
    };
in
suite {
  package = tcl;

  tests = {
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

  // lib.optionalAttrs (features.are or true) {
    # The advanced regexp engine, which replaced the 8.0 one at 8.1.
    regexp-are = {
      script = ''
        tclsh ${./fixtures/regexp-are.tcl}
      '';
      expected = "tvp";
    };
  }

  // lib.optionalAttrs (features.pkgConfig or true) {
    pkg-config = {
      script = ''
        export PKG_CONFIG_LIBDIR=${tcl}/lib/pkgconfig:${tcl}/share/pkgconfig
        ${pkg-config}/bin/pkg-config --modversion tcl
      '';
      expected = tcl.passthru.tvp.pkgConfigVersion or tcl.version;
      extraInputs = [ pkg-config ];
    };
  }

  // lib.optionalAttrs (deps ? zlib) {
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
        LD_TRACE_LOADED_OBJECTS=1 ${tcl}/bin/tclsh | awk '/libz\.so/ { print $3 }' | grep -q "^${deps.zlib.out}/" && printf linked
      '';
      expected = "linked";
      extraInputs = [ ];
    };
  };
}

// lib.optionalAttrs (package.version == "8.6.18") (
  import ./native-contract.nix { inherit package lib context; }
)
// lib.optionalAttrs (package.version == "9.1.0") (
  import ./native-contract-9.1.nix { inherit package lib context; }
)
// lib.optionalAttrs ((features.doCheck or false) && features.bundledPackages) {
  upstream = import ./upstream.nix { inherit package lib context; };
}
