{ lib }:
rec {
  # `expected` is mandatory: `cmd > $out` passes for anything that exits cleanly
  # with no output.
  mkTest =
    {
      pkgs,
      package,
      name,
      script,
      expected,
      extraInputs ? [ ],
    }:
    pkgs.runCommand "${package.pname}-${package.version}-${name}"
      {
        nativeBuildInputs = [ package ] ++ extraInputs;
        passthru = {
          inherit package;
          testName = name;
        };
        meta.description = "TVP ${name} test for ${package.pname} ${package.version}";
      }
      ''
        set -eo pipefail

        actual=$(
        ${script}
        )
        expected=${lib.escapeShellArg expected}

        if [ "$actual" != "$expected" ]; then
          echo "FAIL  ${package.pname} ${package.version} / ${name}" >&2
          echo "  expected: $expected" >&2
          echo "  actual:   $actual" >&2
          exit 1
        fi

        printf '%s\n' "$actual" > "$out"
      '';

  mkSuite =
    {
      pkgs,
      package,
      tests,
    }:
    lib.mapAttrs (name: spec: mkTest ({ inherit pkgs package name; } // spec)) tests;

  # One buildable handle per package, so CI never enumerates tests itself.
  mkBatch =
    {
      pkgs,
      name,
      suite,
    }:
    pkgs.linkFarm "tvp-tests-${name}" (
      lib.mapAttrsToList (name: drv: {
        inherit name;
        path = drv;
      }) suite
    );
}
