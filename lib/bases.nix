{ lib }:
rec {
  # Asserted against the stdenv, never supplied to it.
  mkBase =
    {
      name,
      cc,
      stdenv,
      floor,
      # Required: which base compiled this one. null means nixpkgs bootstrapped it.
      builtBy,
    }:
    let
      # Exact, never a prefix: 13.3 -> 13.4 under one name would redefine what
      # every definition on that base meant.
      actualCC = stdenv.cc.version;
      actualFloor = map (p: p.pname or (builtins.parseDrvName p.name).name) stdenv.initialPath;
    in
    if actualCC != cc then
      throw "TVP: base '${name}' claims gcc ${cc} but its stdenv carries ${stdenv.cc.version}. Add a base for ${actualCC}; do not redefine '${name}'."
    else if actualFloor != floor then
      throw "TVP: base '${name}' floor is not what TVP declares. Declared: ${lib.concatStringsSep " " floor}. stdenv carries: ${lib.concatStringsSep " " actualFloor}."
    else
      {
        inherit
          name
          cc
          floor
          builtBy
          stdenv
          ;
      };

  # A base test runs *on* the base, so it is built by that base's own stdenv
  # rather than by runCommand.
  mkBaseTest =
    {
      base,
      name,
      script,
      expected,
    }:
    base.stdenv.mkDerivation {
      name = "tvp-base-${base.name}-${name}";
      dontUnpack = true;
      dontConfigure = true;
      dontInstall = true;

      passthru = {
        inherit base;
        testName = name;
      };
      meta.description = "TVP ${name} test for base ${base.name}";

      buildPhase = ''
        set -eo pipefail

        actual=$(
        ${script}
        )
        expected=${lib.escapeShellArg expected}

        if [ "$actual" != "$expected" ]; then
          echo "FAIL  base ${base.name} / ${name}" >&2
          echo "  expected: $expected" >&2
          echo "  actual:   $actual" >&2
          exit 1
        fi

        printf '%s\n' "$actual" > "$out"
      '';
    };

  mkBaseSuite =
    { base, tests }: lib.mapAttrs (name: spec: mkBaseTest ({ inherit base name; } // spec)) tests;
}
