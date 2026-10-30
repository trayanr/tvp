{
  pkgs,
  tvpLib,
  package,
}:
let
  deps = package.tvp.deps;
  linkage = dependency: soname: program: {
    script = ''
      paths=$(ldd ${package}/bin/${program} | awk '/${soname}/ { print $3 }')
      test -n "$paths"
      while IFS= read -r path; do
        case "$path" in
          ${pkgs.lib.escapeShellArg "${pkgs.lib.getLib dependency}/"}*) ;;
          *) echo "Unexpected library path: $path" >&2; exit 1 ;;
        esac
      done <<< "$paths"
      printf linked
    '';
    expected = "linked";
    extraInputs = [ pkgs.glibc.bin ];
  };
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
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
    // pkgs.lib.optionalAttrs package.tvp.features.bignum {
      operation = {
        script = ''
          ${package}/bin/gawk -M 'BEGIN { printf "%d\n", 2^128 }'
        '';
        expected = "340282366920938463463374607431768211456";
      };
    }
    // pkgs.lib.optionalAttrs (deps ? gmp) {
      gmp-linkage = linkage deps.gmp "libgmp\\.so" "gawk";
    }
    // pkgs.lib.optionalAttrs (deps ? mpfr) {
      mpfr-linkage = linkage deps.mpfr "libmpfr\\.so" "gawk";
    }
    // pkgs.lib.optionalAttrs (deps ? readline) {
      readline-linkage = linkage deps.readline "libreadline\\.so" package.tvp.readlineProgram;
    }
    // pkgs.lib.optionalAttrs (deps ? ncurses) {
      ncurses-linkage = linkage deps.ncurses "lib(tinfow?|ncursesw?)\\.so" package.tvp.readlineProgram;
    };
}
// import ./behavior.nix { inherit pkgs tvpLib package; }

// import ./tracker.nix { inherit pkgs tvpLib package; }
