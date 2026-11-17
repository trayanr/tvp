# Evaluated reports and ownership registrations; no realization or store scans.
{
  pkgs,
  tvp,
  tvpLib,
  canonical,
  variants,
  construction,
  legacyBases,
  tools,
  checks,
  testBatchEntries,
}:
let
  runtimeRegistry = tvpLib.provenance.registry {
    inherit
      canonical
      variants
      construction
      ;
    bases = legacyBases;
    compositions = tvp.android.profiles;
  };
in
{
  inherit runtimeRegistry;
  upstreamIsolationInventory = tvpLib.upstreamTestIsolation.inventory { inherit canonical variants; };
  upstreamIsolationReport =
    (tvpLib.upstreamTestIsolation.validate {
      inventory = tvp.upstreamIsolationInventory;
    })
    // {
      artifactFinalizationDebt = tvp.recipeSplitReport.counts.remainingDebt;
    };
  upstreamIsolationStrict = tvpLib.upstreamTestIsolation.enforce (
    tvpLib.upstreamTestIsolation.validate {
      inventory = tvp.upstreamIsolationInventory;
      strict = true;
    }
  );
  recipeSplitInventory = tvpLib.recipeSplits.inventory { inherit canonical variants; };
  recipeSplitReport =
    (tvpLib.recipeSplits.validate {
      inventory = tvp.recipeSplitInventory;
      baseline = tvpLib.recipeSplits.baselineFromJSON (builtins.readFile ../audits/split-baseline.json);
    })
    // {
      outsideOrdinaryScope = {
        producers =
          pkgs.lib.mapAttrs
            (id: producer: {
              inherit producer;
              validation = "OUTSIDE_ORDINARY_POLICY_REQUIRES_ADAPTER_AUDIT";
              role = builtins.head (pkgs.lib.splitString "." id);
              disposition = "Separate historical/base/bootstrap/composition adapter audit required.";
            })
            (
              pkgs.lib.filterAttrs (
                id: _: !(pkgs.lib.hasPrefix "packages." id || pkgs.lib.hasPrefix "variants." id)
              ) tvp.graph.entries
            );
        repositoryChecks = builtins.attrNames checks;
        testBatches = builtins.attrNames testBatchEntries;
        testDisposition = "Test/check harnesses and base suites are validation roles, not ordinary production recipes; constructor adapters require separate audit.";
      };
    };
  recipeSplitStrict = tvpLib.recipeSplits.enforce (
    tvpLib.recipeSplits.validate {
      inventory = tvp.recipeSplitInventory;
      strict = true;
    }
  );
  dependencyRoots = import ../lib/dependency-roots.nix {
    inherit (pkgs) lib;
    inherit tools checks;
    graph = tvpLib.graph.snapshot {
      includeRootMetadata = true;
      inherit
        canonical
        variants
        construction
        ;
      bases = legacyBases;
      compositions = tvp.android.profiles;
    };
    inventory = tvp.dependencyInventory;
    registry = runtimeRegistry;
    borrowed = {
      inherit (pkgs) jq shellcheck-minimal;
    };
    borrowedSource = toString pkgs.path;
  };
  dependencyInventory = import ../lib/dependencies.nix {
    inherit
      pkgs
      canonical
      variants
      construction
      ;
    compositions = tvp.android.profiles;
    buildTestSupport = import ../tests/support.nix { inherit pkgs tvp legacyBases; };
  };
  graph = tvpLib.graph.snapshot {
    inherit
      canonical
      variants
      construction
      ;
    bases = legacyBases;
    compositions = tvp.android.profiles;
  };
}
