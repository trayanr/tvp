# One suite, shared by every tcl version. Never fork it per builder: a test that
# exists only for newer versions cannot detect drift in an older one. Guards
# select whole tests; they never edit a test body.
{
  pkgs,
  pkg-config,
  tvpLib,
  tcl,
}:
let
  deps = tcl.passthru.tvp.deps or { };
  owned = tcl ? testContext;
  suite =
    args:
    if !owned then
      tvpLib.tests.mkSuite args
    else
      tcl.testContext.mkSuite {
        inherit (args) package;
        tools = tcl.specification.environment.tools ++ [ tcl.specification.tools.binutils ];
        libraries = [ tcl ];
        tests = builtins.mapAttrs (
          _: spec:
          builtins.removeAttrs spec [ "extraInputs" ]
          // pkgs.lib.optionalAttrs (spec ? extraInputs) {
            tools =
              (builtins.filter (p: (p.pname or "") != "pkg-config") tcl.specification.environment.tools)
              ++ [ tcl.specification.tools.binutils ]
              ++ spec.extraInputs;
          }
        ) args.tests;
      };
  features = tcl.passthru.tvp.features or { };
in
suite {
  inherit pkgs;
  package = tcl;

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
          ${if owned then "${pkg-config}/bin/" else ""}pkg-config --modversion tcl
        '';
        expected = tcl.passthru.tvp.pkgConfigVersion or tcl.version;
        extraInputs = [ pkg-config ];
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
          ${if owned then "LD_TRACE_LOADED_OBJECTS=1" else "ldd"} ${
            if owned then "${tcl}/bin/tclsh" else "\"$lib\""
          } | awk '/libz\.so/ { print $3 }' | grep -q "^${deps.zlib.out}/" && printf linked
        '';
        expected = "linked";
        extraInputs = pkgs.lib.optionals (!owned) [ tcl.tvp.cc.libc.bin ];
      };
    };
}
