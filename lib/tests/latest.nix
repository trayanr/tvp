# Evaluation only: use real alias generation with unbuildable model releases.
{ lib }:
let
  api = import ../default.nix { inherit lib; };
  tests = api.tests;
  leaf = name: rec {
    drvPath = "/model/${name}.drv";
    outPath = "/model/${name}";
    outputs = [
      "out"
      "validation"
    ];
    out.outPath = outPath;
    validation.outPath = "${outPath}-validation";
  };
  release =
    version:
    (leaf "probe-${version}")
    // {
      pname = "probe";
      inherit version;
      tests.value = leaf "probe-${version}-test";
    };
  canonical = {
    probe_2_0 = (release "2.0") // {
      tests = throw "historical tests forced";
      outPath = throw "historical output forced";
      drvPath = throw "historical producer forced";
    };
    probe_10_0 = (release "10.0") // {
      tvp.status.level = "degraded";
    };
    probe_11_0 = (release "11.0") // {
      tvp.status = {
        level = "broken";
        reason = "fixture unsupported";
        needs = "repair";
      };
      tests = throw "broken tests forced";
      outPath = throw "broken output forced";
    };
  };
  packages = api.packages.mkAliases {
    pname = "probe";
    inherit canonical;
    versionTable = {
      "2.0" = { };
      "10.0" = { };
      "11.0".status.level = "broken";
    };
  };
  batch = (leaf "own-context-batch") // {
    testSuite = canonical.probe_10_0.tests;
  };
  batches = {
    probe_10_0 = batch;
    probe_2_0 = throw "historical batch forced";
    all = throw "full aggregate forced";
    variant-profile-probe = throw "variant forced";
    bootstrap-probe = throw "bootstrap forced";
    check-package-runtime-ownership = throw "full ownership forced";
  };
  inputs = {
    inherit canonical packages batches;
  };
  selected = tests.selectLatest inputs;
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  alterAlias = attrs: packages // { probe = packages.probe // attrs; };
  brokenOnly = tests.selectLatest {
    canonical = {
      inherit (canonical) probe_11_0;
    };
    packages = { };
    batches = { };
  };
  checks = {
    semanticLatest = selected.metadata.families.probe.version == "10.0";
    aliasPolicy = selected.metadata.families.probe.selector == packages.probe.__tvpSelection;
    exactBatch = selected.batches.probe_10_0 == batch;
    ordinaryOnly = builtins.attrNames selected.batches == [ "probe_10_0" ];
    deterministic = selected.metadata == (tests.selectLatest inputs).metadata;
    contextFree = !(builtins.hasContext (builtins.toJSON selected.metadata));
    missingAlias = rejects (tests.selectLatest (inputs // { packages = { }; }));
    staleAlias = rejects (
      tests.selectLatest (
        inputs
        // {
          canonical = canonical // {
            probe_2_0 = release "2.0";
          };
          packages = packages // {
            probe = (release "2.0") // {
              __tvpSelection = packages.probe.__tvpSelection // {
                canonical = "probe_2_0";
                version = "2.0";
              };
            };
          };
        }
      )
    );
    brokenAlias = rejects (
      tests.selectLatest (
        inputs
        // {
          packages = alterAlias {
            __tvpSelection = packages.probe.__tvpSelection // {
              canonical = "probe_11_0";
            };
          };
        }
      )
    );
    foreignAlias = rejects (
      tests.selectLatest (
        inputs
        // {
          packages = alterAlias {
            __tvpSelection = packages.probe.__tvpSelection // {
              namespace = "variants.profile";
            };
          };
        }
      )
    );
    mismatchedAlias = rejects (
      tests.selectLatest (
        inputs
        // {
          packages = alterAlias { outPath = "/model/different-output"; };
        }
      )
    );
    mismatchedAliasMetadata = rejects (
      tests.selectLatest (
        inputs
        // {
          packages = alterAlias {
            __tvpSelection = packages.probe.__tvpSelection // {
              version = "wrong";
            };
          };
        }
      )
    );
    missingBatch = rejects (tests.selectLatest (inputs // { batches = { }; }));
    mismatchedBatch = rejects (
      tests.selectLatest (
        inputs
        // {
          batches.probe_10_0 = batch // {
            testSuite.value = leaf "different-test";
          };
        }
      )
    );
    mismatchedNamedOutput = rejects (
      tests.selectLatest (
        inputs
        // {
          batches.probe_10_0 = batch // {
            testSuite.value = canonical.probe_10_0.tests.value // {
              outPath = canonical.probe_10_0.tests.value.validation.outPath;
            };
          };
        }
      )
    );
    missingTests = rejects (
      tests.selectLatest (
        inputs
        // {
          canonical = canonical // {
            probe_10_0 = canonical.probe_10_0 // {
              tests = { };
            };
          };
        }
      )
    );
    allBrokenDiagnostic =
      brokenOnly.batches == { }
      && (builtins.head brokenOnly.metadata.skipped).family == "probe"
      &&
        (builtins.head (builtins.head brokenOnly.metadata.skipped).releases).reason
        == "fixture unsupported";
    empty =
      (tests.selectLatest {
        canonical = { };
        packages = { };
        batches = { };
      }).metadata == {
        schema = "tvp.latest-tests/v1";
        families = { };
        skipped = [ ];
      };
    # Reuse the existing collision contract at the job composition boundary.
    duplicateJobs = rejects (
      tests.suiteJobs {
        batches.check-probe = batch;
        checks.probe = batch;
      }
    );
  };
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) checks);
in
if failed != [ ] then
  throw "TVP latest test contracts failed: ${lib.concatStringsSep ", " failed}"
else
  checks
