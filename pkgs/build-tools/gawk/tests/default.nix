# One installed-suite factory for the whole ordinary family.
{
  package,
  lib,
  context,
}:
let
  locale = context.fixtures.gnuLocale;
in

let
  deps = package.tvp.deps;
  linkage = dependency: soname: program: {
    script = ''
      paths=$(LD_TRACE_LOADED_OBJECTS=1 ${package}/bin/${program} | awk '/${soname}/ { print $3 }')
      test -n "$paths"
      while IFS= read -r path; do
        case "$path" in
          ${lib.escapeShellArg "${lib.getLib dependency}/"}*) ;;
          *) echo "Unexpected library path: $path" >&2; exit 1 ;;
        esac
      done <<< "$paths"
      printf linked
    '';
    expected = "linked";
    tools = package.specification.environment.tools;
  };
in
context.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [ package.specification.base.compiler.bintools ];
  tests =
    {
      version = {
        script = ''
          ${package}/bin/gawk --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | sed -n '1p'
        '';
        expected = package.version;
      };
      core = {
        script = ''
          printf 'alpha 2\nbeta 3\nalpha 5\n' | ${package}/bin/gawk '{sum[$1] += $2} END {printf "%d %d\n", sum["alpha"], sum["beta"]}'
        '';
        expected = "7 3";
      };
    }
    // lib.optionalAttrs package.tvp.features.bignum {
      operation = {
        script = ''
          ${package}/bin/gawk -M 'BEGIN { printf "%d\n", 2^128 }'
        '';
        expected = "340282366920938463463374607431768211456";
      };
    }
    // lib.optionalAttrs (deps ? gmp) {
      gmp-linkage = linkage deps.gmp "libgmp\\.so" "gawk";
    }
    // lib.optionalAttrs (deps ? mpfr) {
      mpfr-linkage = linkage deps.mpfr "libmpfr\\.so" "gawk";
    }
    // lib.optionalAttrs (deps ? readline) {
      readline-linkage = linkage deps.readline "libreadline\\.so" package.tvp.readlineProgram;
    }
    // lib.optionalAttrs (deps ? ncurses) {
      ncurses-linkage = linkage deps.ncurses "lib(tinfow?|ncursesw?)\\.so" package.tvp.readlineProgram;
    };
}
// import ./behavior.nix { inherit package lib context; }

// import ./tracker.nix { inherit package lib context; }

// lib.optionalAttrs package.specification.installedInterface.hasNls (
  import ./native-nls.nix { inherit package locale; }
)
// lib.optionalAttrs (deps ? readline) {
  debugger-line-edit = import (
    if package.tvp.readlineProgram == "dgawk" then ./ordinary-debugger.nix else ./native-debugger.nix
  ) { inherit package; };
}

// import ../../ordinary-text-contracts.nix { inherit package lib context; }
// import ../../text-tool-upstream.nix { inherit package lib context; }
