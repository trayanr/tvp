{ lib, platforms }:
rec {
  # Asserted against the stdenv, never supplied to it.
  mkBase =
    {
      name,
      cc,
      binutils,
      libc,
      stdenv,
      floor,
      # Required: which base compiled this one. null means nixpkgs bootstrapped it.
      builtBy,
    }:
    let
      # Exact, never a prefix: 13.3 -> 13.4 under one name would redefine what
      # every definition on that base meant.
      actualCC = stdenv.cc.version;
      actualBinutils = stdenv.cc.bintools.version;
      actualLibc = stdenv.cc.libc.version;
      actualFloor = map (p: p.pname or (builtins.parseDrvName p.name).name) stdenv.initialPath;
    in
    if actualCC != cc then
      throw "TVP: base '${name}' claims gcc ${cc} but its stdenv carries ${stdenv.cc.version}. Add a base for ${actualCC}; do not redefine '${name}'."
    else if actualBinutils != binutils then
      throw "TVP: base '${name}' claims binutils ${binutils} but its stdenv carries ${actualBinutils}. Add a new base; do not redefine '${name}'."
    else if actualLibc != libc then
      throw "TVP: base '${name}' claims glibc ${libc} but its stdenv carries ${actualLibc}. Add a new base; do not redefine '${name}'."
    else if actualFloor != floor then
      throw "TVP: base '${name}' floor is not what TVP declares. Declared: ${lib.concatStringsSep " " floor}. stdenv carries: ${lib.concatStringsSep " " actualFloor}."
    else
      {
        inherit
          name
          cc
          binutils
          libc
          floor
          builtBy
          stdenv
          ;
        platform = platforms.forStdenv stdenv;
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

  # An ownership audit only needs roots and allowed outputs. It does not imply
  # any compiler family, optional tools, component layout or consumer suite.
  mkOwnershipTest =
    {
      pkgs,
      base,
      name,
      roots,
      allowedRuntimePaths,
    }:
    mkBaseTest {
      inherit base name;
      script =
        let
          closure = pkgs.closureInfo { rootPaths = roots; };
          allowed = pkgs.writeText "tvp-${name}-paths" (
            lib.concatMapStrings (path: "${path}\n") allowedRuntimePaths
          );
        in
        ''
          foreign=0
          while IFS= read -r path; do
            if ! grep -Fx "$path" ${allowed} > /dev/null; then
              echo "unowned runtime dependency: $path" >&2
              foreign=1
            fi
          done < ${closure}/store-paths
          test "$foreign" = 0
          echo ok
        '';
      expected = "ok";
    };
}
