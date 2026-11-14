# Scoped source/evaluation contracts only. No realization or runtime qualification.
{ pkgs, tvp }:
let
  inherit (tvp.builder) steps;
  inherit (pkgs) lib;
  selected = {
    go_1_27_3 = tvp.canonical.go_1_27_3;
    nodejs_26_13_0 = tvp.canonical.nodejs_26_13_0;
    git_2_56_0 = tvp.canonical.git_2_56_0;
    less_710 = tvp.canonical.less_710;
  };
  plain = builtins.unsafeDiscardStringContext;
  bump =
    _:
    tvp.builder {
      recipe =
        { }:
        _: {
          pname = "runtime-tools-source-contract";
          version = "1";
          src = null;
          inherit (tvp.canonical.go_1_27_3.specification) base bash coreutils;
          plan = [
            {
              name = "contract.provider";
              run = "mkdir $out";
            }
          ];
        };
      args = { };
      dependencyNames = [ ];
      metadata = { };
      selection = { };
      mkTests = _: { };
    };
  changedFinal =
    p:
    p.editSteps (
      steps.replace "output.check-paths" (x: x // { run = x.run + "\n# source contract\n"; })
    );
  consumes =
    p: q:
    builtins.hasAttr (plain q.drvPath) (
      builtins.getContext (
        builtins.toJSON {
          inherit (p.buildStepRunner) inputs childScripts text;
        }
      )
    );
  rows = builtins.mapAttrs (
    name: p:
    let
      f = changedFinal p;
      s = p.specification;
      construction = p.edit (x: x // { bash = bump x.bash; });
      noCheck = p.edit (x: x // { doCheck = false; });
      upstream = if name == "go_1_27_3" then p.tests.standard-library else p.tests.upstream;
      raw = if name == "go_1_27_3" then upstream else upstream.specification.validation.execution;
      runtime =
        if name == "go_1_27_3" then
          p.editRuntime (r: r // { cc = r.cc + "-source-contract"; })
        else
          p.editRuntime (r: r // { shell = bump r.shell; });
      upstreamEdited =
        if name == "go_1_27_3" then upstream else (p.edit (x: x // { doCheck = false; })).tests.upstream;
      finalLibraries = if name == "go_1_27_3" then f else p.editRuntime (r: r // { libraries = [ ]; });
      # Tiny fixtures select cached validation tools through the public edit API;
      # canonical production providers are never built for a source contract.
      fixture = runtime.edit (
        x:
        x
        // {
          coreutils = (import ../../bases/source-gnu { }).tools.coreutils;
          helperPython = pkgs.python3;
          toolPython = pkgs.python3;
          python = pkgs.python3;
          binutils = (import ../../bases/source-gnu { }).tools.binutils;
        }
      );
      tests = builtins.mapAttrs (_: t: plain t.drvPath) p.tests;
      contracts =
        {
          noop = (p.override { }).drvPath == p.drvPath;
          split = p.artifact.drvPath != p.drvPath;
          singleOutput = p.outputs == [ "out" ] && p.artifact.outputs == [ "out" ];
          copy = builtins.any (
            x:
            x.name == "output.copy-artifacts"
            && lib.hasInfix "TVP_ARTIFACT_ROOT" x.run
            && !(lib.hasInfix "TVP_ARTIFACT_OUTPUTS" x.run)
          ) p.buildSteps;
          finalReusesA = f.artifact.drvPath == p.artifact.drvPath && f.drvPath != p.drvPath;
          constructionChangesA = construction.artifact.drvPath != p.artifact.drvPath;
          noCheckReusesAandF = noCheck.artifact.drvPath == p.artifact.drvPath && noCheck.drvPath == p.drvPath;
          runtimeClassification =
            if
              builtins.elem name [
                "go_1_27_3"
                "nodejs_26_13_0"
              ]
            then
              runtime.artifact.drvPath != p.artifact.drvPath
            else
              runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
          lookupLibrariesReuseA = finalLibraries.artifact.drvPath == p.artifact.drvPath;
          productionIndependent =
            !(consumes p raw)
            && !(consumes p.artifact raw)
            && !(consumes p upstream)
            && !(consumes p.artifact upstream);
          upstreamRegistered = upstream.package.drvPath == p.drvPath;
          validationTargetPolicy =
            if name == "less_710" then
              builtins.any (
                x: lib.hasInfix "LESSTEST=1" (x.run or "") && lib.hasInfix "../less_t lt" (x.run or "")
              ) raw.buildSteps
            else
              consumes raw p;
          noCheckChangesValidation = name == "go_1_27_3" || upstreamEdited.drvPath != upstream.drvPath;
          factoryRegistration =
            if name == "go_1_27_3" then
              p.tests.standard-library.package.drvPath == p.drvPath
            else
              upstream.specification.validation.factory == "owned.mkTest"
              && upstream.specification.validation.production.drvPath == p.artifact.drvPath;
        }
        // lib.optionalAttrs (name == "go_1_27_3") {
          cxxChangesA =
            (p.editRuntime (r: r // { cxx = r.cxx + "-contract"; })).artifact.drvPath != p.artifact.drvPath;
          loaderChangesA =
            (p.editRuntime (r: r // { loader = "${r.libc}/lib/contract-loader"; })).artifact.drvPath
            != p.artifact.drvPath;
          compilerChangesA =
            (p.editRuntime (
              r: r // { compiler = (import ../../bases/source-gnu/tests/probes.nix { }).sentinel; }
            )).artifact.drvPath != p.artifact.drvPath;
          incoherentLibcRejected =
            !(builtins.tryEval (p.editRuntime (r: r // { libc = bump r.libc; })).artifact.drvPath).success;
        }
        //
          lib.optionalAttrs
            (builtins.elem name [
              "git_2_56_0"
              "nodejs_26_13_0"
            ])
            {
              configurePrefixChangesA =
                (p.edit (x: x // { configurePrefix = "/tvp/contract"; })).artifact.drvPath != p.artifact.drvPath;
              storeConfigurePrefixRejected =
                !(builtins.tryEval (p.edit (x: x // { configurePrefix = toString p; })).artifact.drvPath).success;
              escapingConfigurePrefixRejected =
                !(builtins.tryEval (p.edit (x: x // { configurePrefix = "/tvp/../../escape"; })).artifact.drvPath)
                .success;
            }
        // lib.optionalAttrs (name == "git_2_56_0") {
          cvsserverEntryPathsRegistered =
            p.tests.cvsserver-entry-paths.tvp.kind == "owned-test"
            && p.tests.cvsserver-entry-paths.package.drvPath == p.drvPath;
          privatePreparationReusesAandF =
            let
              q = p.edit (
                x:
                x
                // {
                  upstreamPreparation = x.upstreamPreparation // {
                    run = x.upstreamPreparation.run + "\n# private test preparation\n";
                  };
                }
              );
            in
            q.artifact.drvPath == p.artifact.drvPath
            && q.drvPath == p.drvPath
            && q.tests.upstream.drvPath != p.tests.upstream.drvPath;
        };
    in
    {
      inherit contracts tests;
      identities = {
        artifact = plain p.artifact.drvPath;
        artifactOut = plain p.artifact.outPath;
        final = plain p.drvPath;
        finalOut = plain p.outPath;
        upstream = plain upstream.drvPath;
        upstreamOut = plain upstream.outPath;
        raw = plain raw.drvPath;
        rawOut = plain raw.outPath;
      };
      # Actual selected commands are inputs to shell-syntax and copy fixtures.
      commands = map (x: {
        inherit (x) name;
        run = plain (x.run or "");
      }) (builtins.filter (x: (x.kind or "command") != "split") p.buildSteps);
      fixtureCommands = map (x: {
        inherit (x) name;
        run = plain (x.run or "");
      }) (builtins.filter (x: (x.kind or "command") != "split") fixture.buildSteps);
      runtimeCommands = map (x: {
        inherit (x) name;
        run = plain (x.run or "");
      }) (builtins.filter (x: (x.kind or "command") != "split") runtime.buildSteps);
      upstreamCommands = map (x: {
        inherit (x) name;
        run = plain (x.run or "");
      }) raw.buildSteps;
    }
  ) selected;
  inventory = tvp.lib.recipeSplits.inventory { canonical = selected; };
  baseline = builtins.filter (x: builtins.elem x.id (map (r: r.id) inventory.rows)) (
    builtins.fromJSON (builtins.readFile ../../audits/split-baseline.json)
  );
  failures = lib.concatMap (
    name:
    map (c: "${name}.${c}") (
      builtins.filter (c: !rows.${name}.contracts.${c}) (builtins.attrNames rows.${name}.contracts)
    )
  ) (builtins.attrNames rows);
in
{
  inherit rows inventory failures;
  fixturePerl = plain "${(import ../../bases/source-gnu { }).tools.perl}/bin/perl";
  success = failures == [ ] && builtins.all (r: r.compliant) inventory.rows;
  scopedBaseline = tvp.lib.recipeSplits.validate { inherit inventory baseline; };
}
