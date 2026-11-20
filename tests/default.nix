# Assemble existing suites without forcing historical tests during latest selection.
{
  pkgs,
  tvp,
  tvpLib,
  canonical,
  packages,
  legacyBases,
  construction,
  variantPackages,
  checks,
}:
let
  allVariantPackages =
    tvpLib.packages.merge (
      pkgs.lib.mapAttrs (
        profile: entries:
        pkgs.lib.mapAttrs' (
          name: package: pkgs.lib.nameValuePair "bootstrap-${profile}-${name}" package
        ) entries
      ) construction.variants
    )
    // variantPackages;

  # Keep this mapping lazy: latest selection must not enumerate historical suites
  # just to find the selected batch. Full coverage retains its existing filter.
  packageTestBatches = builtins.mapAttrs (
    name: pkg:
    (
      if pkg ? testContext then
        pkg.testContext.mkBatch
      else
        args: tvpLib.tests.compatibility.mkBatch (args // { inherit pkgs; })
    )
      {
        inherit name;
        suite = pkg.tests;
      }
  ) canonical;

  testBatchEntries = tvpLib.packages.merge {
    phpExtensions = tvp.php.extensionTests;
    packages = pkgs.lib.filterAttrs (
      name: _:
      let
        pkg = canonical.${name};
      in
      pkg ? tests && pkg.tests != { } && (pkg.tvp.status.level or "ok") != "broken"
    ) packageTestBatches;
    bases = pkgs.lib.mapAttrs' (
      name: base:
      pkgs.lib.nameValuePair "base-${name}" (
        tvpLib.tests.compatibility.mkBatch {
          inherit pkgs;
          name = "base-${name}";
          suite = base.tests;
        }
      )
    ) (pkgs.lib.filterAttrs (name: base: base.name == name) legacyBases);
    bootstrapBases = pkgs.lib.mapAttrs' (
      name: base:
      pkgs.lib.nameValuePair "bootstrap-base-${name}" (
        tvpLib.tests.compatibility.mkBatch {
          inherit pkgs;
          name = "bootstrap-base-${name}";
          suite = base.tests;
        }
      )
    ) construction.bases;
    variants = pkgs.lib.mapAttrs (
      name: package:
      (
        if package ? testContext then
          package.testContext.mkBatch
        else
          args: tvpLib.tests.compatibility.mkBatch (args // { inherit pkgs; })
      )
        {
          inherit name;
          suite = package.tests;
        }
    ) (pkgs.lib.filterAttrs (_: p: (p.tvp.status.level or "ok") != "broken") allVariantPackages);
  };

  testBatches = testBatchEntries // {
    all = tvpLib.tests.compatibility.mkAll {
      inherit pkgs checks;
      batches = testBatchEntries;
    };
  };

  compatibility = tvpLib.tests.compatibility;
  plain = builtins.unsafeDiscardStringContext;
  supported = pkgs.lib.filterAttrs (_: package: (package.tvp.status.level or "ok") != "broken");
  cataloguePackages = tvpLib.packages.merge {
    inherit canonical;
    variants = variantPackages;
  };
  # These installed interfaces are tested outside the ordinary package suites.
  baseConsumerSubjects = pkgs.lib.mapAttrs' (
    name: base:
    pkgs.lib.nameValuePair "base-${name}" {
      package = base.ownedBase.compiler;
      tests = { inherit (base.tests) compile cxx; };
    }
  ) (pkgs.lib.filterAttrs (name: base: base.name == name) legacyBases);
  builtinOpcacheSubjects =
    let
      php = packages.php;
      phpName = tvpLib.versions.attrName "php" php.version;
      extensions = import ../pkgs/runtimes/php/extensions { inherit pkgs tvp; };
    in
    pkgs.lib.optionalAttrs (extensions.builtIn php "opcache") {
      "${phpName}--opcache-builtin" = {
        package = php;
        tests =
          import ../pkgs/runtimes/php/extensions/opcache/tests.nix
            {
              inherit tvp;
              builtIn = true;
            }
            {
              inherit (pkgs) lib;
              package = php;
              context = php.testContext;
            };
      };
    };
  interfaceSubjects = baseConsumerSubjects // builtinOpcacheSubjects;
  catalogueSubjects = tvpLib.packages.merge {
    packages = builtins.mapAttrs (_: package: {
      inherit package;
      tests = package.tests or { };
    }) (supported cataloguePackages);
    phpExtensions = tvp.php.extensionMatrix;
    installedInterfaces = interfaceSubjects;
  };
  # Older tests use named upstream leaves. Newer checkpoints also expose the
  # separate raw execution. Keep installed checks which exercise upstream data.
  installedChecks = pkgs.lib.filterAttrs (
    name: test:
    !(builtins.elem name [
      "upstream"
      "upstream-audit"
      "upstream-basic"
      "upstream-evidence"
      "upstream-profile"
      "upstream-python"
      "upstream-record"
      "upstream-shipped"
      "upstream-ssl"
    ])
    && !(test ? upstreamExecution || test ? passthru.upstreamExecution)
  );
  outputSet = producer: pkgs.lib.genAttrs (producer.outputs or [ "out" ]) (name: producer.${name});
  catalogueJobs = builtins.mapAttrs (
    name: subject:
    let
      checks = installedChecks subject.tests;
      producers = {
        package = subject.package;
      }
      // pkgs.lib.optionalAttrs (subject.package ? artifact) {
        inherit (subject.package) artifact;
      };
      # Link each selected output, including split compilation products whose
      # paths deliberately do not survive in the final package.
      builds = builtins.listToAttrs (
        builtins.concatLists (
          pkgs.lib.mapAttrsToList (
            role: producer:
            pkgs.lib.mapAttrsToList (output: value: pkgs.lib.nameValuePair "produce-${role}-${output}" value) (
              outputSet producer
            )
          ) producers
        )
      );
      batch = compatibility.mkBatch {
        inherit pkgs;
        name = "catalogue-${name}";
        suite = tvpLib.packages.merge { inherit builds checks; };
      };
    in
    assert checks != { } || throw "TVP catalogue: ${name} has no installed checks";
    {
      # Production dependencies are real links in the batch. Keep the result
      # counts and the named test metadata specific to installed checks.
      batch = batch // {
        testSuite = checks;
      };
      productions = pkgs.lib.mapAttrsToList (role: producer: {
        inherit role;
        drv = builtins.unsafeDiscardOutputDependency producer.drvPath;
        outputs = builtins.mapAttrs (_: output: plain output.outPath) (outputSet producer);
      }) producers;
    }
  ) catalogueSubjects;
  cataloguePlan =
    { source, revision }:
    let
      batches = builtins.mapAttrs (_: entry: entry.batch) catalogueJobs;
      aggregate = compatibility.mkAll {
        inherit pkgs batches;
        checks = { };
      };
      plan = compatibility.manifest {
        inherit
          pkgs
          aggregate
          source
          revision
          ;
        entries = compatibility.planEntries {
          jobs = batches;
          smoke = false;
        };
        canonical = cataloguePackages;
      };
    in
    builtins.toFile "tvp-catalogue-plan.json" (
      builtins.toJSON (
        plan
        // {
          validationScope = "catalogue";
          aggregateOutputs = [ (plain aggregate.outPath) ];
          jobs = map (job: job // { inherit (catalogueJobs.${job.name}) productions; }) plan.jobs;
        }
      )
    );

  # Separate from testBatches: the full plan enumerates every entry but `all`.
  # Reuse each package's existing testContext batch without reconstructing it.
  latestSelection = tvpLib.tests.selectLatest {
    inherit canonical packages;
    batches = packageTestBatches;
  };
  latestTests = latestSelection // {
    all = tvpLib.tests.mkLatest {
      context = tvpLib.tests.fromPackage {
        builder = tvp.builder;
        package = packages.coreutils;
      };
      selection = latestSelection;
    };
  };
  smokeTests = import ./smoke.nix { inherit pkgs tvp interfaceSubjects; };
in
{
  # The flattened variants are a private handle shared with the check registry.
  inherit
    testBatches
    latestTests
    smokeTests
    testBatchEntries
    allVariantPackages
    cataloguePlan
    ;
}
