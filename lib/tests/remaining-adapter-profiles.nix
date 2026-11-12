# Pure bounded source contracts; this file never realizes a target or test.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps;
  canonicalNames = [
    "android-build-tools_36_0_0"
    "android-ndk_28_2_13676358"
    "android-platform_36_r2"
    "android-platform_36_1_r1"
    "android-platform_37_0_r2"
    "android-platform_37_1_r1"
    "dart-bootstrap_3_13_0_103_1_beta"
  ];
  canonical = lib.genAttrs canonicalNames (n: tvp.canonical.${n});
  variants = {
    ncurses64.readline_8_3 = tvp.variants.ncurses64.readline_8_3;
    build-steps.fontconfig_2_18_3 = tvp.variants.build-steps.fontconfig_2_18_3;
  };
  inventory = tvp.lib.recipeSplits.inventory { inherit canonical variants; };
  report = tvp.lib.recipeSplits.validate {
    inherit inventory;
    strict = true;
  };
  packages = canonical // {
    readline = variants.ncurses64.readline_8_3;
    fontconfig = variants.build-steps.fontconfig_2_18_3;
  };
  row =
    p:
    let
      d = p.specification;
      parts = steps.partition p.buildSteps;
      noOp = p.edit (s: s);
      source = p.override { src = builtins.toFile "adapter-profile-source-control" "changed-source"; };
      suffix = p.editSteps (
        plan:
        plan
        ++ [
          {
            name = "source-contract.final-control";
            run = "true";
          }
        ]
      );
      runtime = p.editRuntime (r: r // { libraries = (r.libraries or [ ]) ++ [ d.coreutils ]; });
      changedTool = p.override {
        coreutils = d.coreutils // {
          outPath = "/nix/store/00000000000000000000000000000000-coreutils-control";
        };
      };
      finalTool = p.override {
        patchelf = d.patchelf // {
          outPath = "/nix/store/00000000000000000000000000000000-patchelf-control";
        };
      };
      construction = p.editSteps (
        steps.insertBefore
          "${p.pname}.install${
            if p.pname == "dart-bootstrap" then
              "-pristine"
            else if
              builtins.elem p.pname [
                "android-build-tools"
                "android-ndk"
                "android-platform"
              ]
            then
              "-payload"
            else
              ""
          }"
          [
            {
              name = "source-contract.construction-control";
              run = "true";
            }
          ]
      );
      testGuard = if d ? testsEnabled then p.edit (s: s // { testsEnabled = false; }) else p;
      selected = builtins.head (builtins.attrNames p.tests);
      test = p.tests.${selected};
      ownedTest = p.tests.${if p.pname == "fontconfig" then "consumer" else selected};
      testOnly = ownedTest.editSteps (
        plan:
        plan
        ++ [
          {
            name = "source-contract.test-control";
            run = "true";
          }
        ]
      );
      disabled = if d ? doCheck then p.override { doCheck = false; } else p;
      commands = q: lib.concatMapStringsSep "\n" (s: s.run or "") q.buildSteps;
    in
    {
      realSplit =
        parts.split && parts.first != [ ] && parts.second != [ ] && p.artifact.drvPath != p.drvPath;
      realArtifact = builtins.any (s: lib.hasInfix "install" s.name) parts.first;
      copyFirst = (builtins.head parts.second).name == "output.copy-artifacts";
      noUpstreamInProduction =
        !builtins.any (s: lib.hasInfix "check" s.name && !(lib.hasPrefix "output." s.name)) parts.first;
      noOpIdentity = noOp.drvPath == p.drvPath && noOp.artifact.drvPath == p.artifact.drvPath;
      noOpOverride = (p.override { }).drvPath == p.drvPath;
      constructionEditInvalidates = construction.artifact.drvPath != p.artifact.drvPath;
      finalToolReuse = finalTool.artifact.drvPath == p.artifact.drvPath;
      finalToolEffective =
        p.pname == "android-platform"
        || (finalTool.drvPath != p.drvPath && lib.hasInfix "patchelf-control" (commands finalTool));
      testGuardIsolation =
        testGuard.artifact.drvPath == p.artifact.drvPath
        && testGuard.drvPath == p.drvPath
        && (!(d ? testsEnabled) || testGuard.tests == { });
      sourceInvalidates = source.artifact.drvPath != p.artifact.drvPath;
      sourceDrivesCommand = lib.hasInfix (builtins.unsafeDiscardStringContext (toString source.specification.src)) (
        commands source
      );
      finalOnlyReuse = suffix.artifact.drvPath == p.artifact.drvPath && suffix.drvPath != p.drvPath;
      runtimeReuse = runtime.artifact.drvPath == p.artifact.drvPath;
      runtimeEffective = p.pname == "android-platform" || runtime.drvPath != p.drvPath;
      toolEffective =
        changedTool.artifact.drvPath != p.artifact.drvPath
        && lib.hasInfix "coreutils-control" (commands changedTool);
      checkGuardReuse = disabled.artifact.drvPath == p.artifact.drvPath && disabled.drvPath == p.drvPath;
      testsRegistered = p.tests != { };
      runtimeTestsRebound =
        runtime.drvPath == p.drvPath || runtime.tests.${selected}.drvPath != test.drvPath;
      testsRebound = suffix.tests.${selected}.drvPath != test.drvPath;
      testOnlyIsolation = testOnly.drvPath != ownedTest.drvPath && testOnly.package.drvPath == p.drvPath;
      originalStatus = p.tvp.status.level == "ok";
      metadataPresent = p.meta ? license && p.meta ? description;
      allOutputTransport =
        p.outputs == p.artifact.outputs
        && builtins.all (n: p.${n}.artifact.drvPath == p.artifact.drvPath) p.outputs;
    };
  rows = builtins.mapAttrs (_: row) packages;
  failed = builtins.mapAttrs (_: r: builtins.filter (n: !r.${n}) (builtins.attrNames r)) rows;
  fc = packages.fontconfig;
  rl = packages.readline;
  retainedNcurses =
    (tvp.lib.packages.mkVersions
      (import ../../pkgs/libraries/ncurses { inherit pkgs tvp; }).recipes.ncurses.constructionRecipe
    ).ncurses_6_4;
  profiles = {
    buildToolsJdkGeneration =
      packages.android-build-tools_36_0_0.tvp.deps.jdk.drvPath
      == (import ../../sdks/retained-adapters.nix { inherit pkgs tvp; })
      .buildTools.versionTable."36.0.0".def.deps.jdk.drvPath;
    platformFinalPolicyReuse =
      let
        p = packages.android-platform_36_r2;
        changed = p.override {
          packageMetadata = builtins.toFile "adapter-metadata-control" "changed-metadata";
        };
      in
      changed.artifact.drvPath == p.artifact.drvPath && changed.drvPath != p.drvPath;
    fontconfigRuntimeExpectation =
      let
        p = fc.editRuntime (r: r // { libraries = r.libraries ++ [ fc.specification.coreutils ]; });
      in
      p.tests.runtime-expectation.expectedLibraries
      == map (x: builtins.unsafeDiscardStringContext (toString x)) p.runtime.libraries;
    readlineProvider = rl.tvp.deps.ncurses.drvPath == retainedNcurses.drvPath;
    readlineStaticShared = rl.tvp.features.static && rl.tvp.features.shared && rl.tvp.features.history;
    readlineLinkage = builtins.any (
      s: lib.hasInfix "SHLIB_LIBS=-lncursesw" (s.run or "")
    ) rl.buildSteps;
    fontconfigPublicOutputs = fc.outputs == [ "out" ];
    fontconfigTestsCompiled = builtins.any (
      s: lib.hasInfix "-Dtests=enabled" (s.run or "")
    ) (steps.partition fc.buildSteps).first;
    fontconfigSeparateUpstream = fc.tests ? upstream && fc.tests.upstream.drvPath != fc.drvPath;
  };
in
assert builtins.all (r: r == [ ]) (builtins.attrValues failed) || throw (builtins.toJSON failed);
assert builtins.all (x: x) (builtins.attrValues profiles) || throw (builtins.toJSON profiles);
{
  inherit rows profiles report;
}
