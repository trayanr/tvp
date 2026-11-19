# Evaluated reports and ownership registrations; no realization or store scans.
{
  pkgs,
  tvp,
  tvpLib,
  canonical,
  variants,
  variantPackages,
  construction,
  legacyBases,
  tools,
  checks,
  testBatchEntries,
}:
let
  compositions =
    tvp.android.profiles
    // pkgs.lib.mapAttrs' (
      name: package: pkgs.lib.nameValuePair "php-${name}" package
    ) tvp.php.profiles;
  runtimeRegistry = tvpLib.provenance.registry {
    inherit
      canonical
      variants
      construction
      ;
    bases = legacyBases;
    inherit compositions;
  };
  policyInventories = tvpLib.upstreamTestIsolation.inventories { inherit canonical variants; };
in
{
  inherit runtimeRegistry;
  provenanceDeclarations = import ./provenance.nix {
    inherit (pkgs) lib;
    inherit tvpLib canonical variantPackages;
    registry = runtimeRegistry;
  };
  upstreamIsolationInventory = policyInventories.upstreamIsolation;
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
  recipeSplitInventory = policyInventories.recipeSplits;
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
      inherit compositions;
    };
    inventory = tvp.dependencyInventory;
    registry = runtimeRegistry;
    borrowed = {
      inherit (pkgs)
        icu
        oniguruma
        postgresql_16
        openssl
        krb5
        keyutils
        tzdata
        expat
        jq
        shellcheck-minimal
        ;
      "mariadb.server" = pkgs.mariadb.server;
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
    inherit compositions;
    buildTestSupport = import ../tests/support.nix { inherit pkgs tvp legacyBases; };
  };
  graph = tvpLib.graph.snapshot {
    inherit
      canonical
      variants
      construction
      ;
    bases = legacyBases;
    inherit compositions;
  };
}
