# Tiny opt-in integration fixture. Never included in the real latest/full jobs.
# Inspect `nix build --dry-run` before building; all non-fixture inputs must exist.
{
  tvp,
  fail ? false,
}:
let
  inherit (tvp.packages) bash coreutils;
  context = tvp.lib.tests.fromPackage {
    inherit (tvp) builder;
    package = coreutils;
  };
  primitive =
    name: body: outputs:
    builtins.derivation {
      inherit name outputs;
      system = "x86_64-linux";
      builder = "${bash}/bin/bash";
      args = [
        "-euc"
        body
      ];
      PATH = "${coreutils}/bin";
    };
  release =
    version:
    (primitive "latest-fixture-${version}" ''
      mkdir "$out"
      printf '%s' '${version}' > "$out/version"
    '' [ "out" ])
    // {
      pname = "fixture";
      inherit version;
    };
  package = release "10.0";
  suite =
    (context.mkSuite {
      inherit package;
      tests.version = {
        script = "cat ${package}/version";
        expected = if fail then "intentional mismatch" else "10.0";
      };
    })
    // {
      named =
        (primitive "latest-fixture-named-test"
          ''
            mkdir "$out" "$validation"
            printf validation > "$validation/kind"
          ''
          [
            "out"
            "validation"
          ]
        ).validation;
    };
  canonical = {
    fixture_2_0 = (release "2.0") // {
      tests = throw "historical fixture suite forced";
    };
    fixture_10_0 = package // {
      tests = suite;
    };
  };
  packages = tvp.lib.packages.mkAliases {
    pname = "fixture";
    inherit canonical;
    versionTable = {
      "2.0" = { };
      "10.0" = { };
    };
  };
  batches.fixture_10_0 = context.mkBatch {
    name = "fixture-10";
    inherit suite;
  };
  selected = tvp.lib.tests.selectLatest { inherit canonical packages batches; };
in
{
  latest = tvp.lib.tests.mkLatest {
    name = "latest-fixture";
    inherit context;
    selection = selected;
  };
  # An intentional sentinel failure would appear in logs if stage two started.
  full = primitive "latest-fixture-full-sentinel" ''
    echo FULL_STAGE_SENTINEL_STARTED >&2
    exit 79
  '' [ "out" ];
  inherit selected;
}
