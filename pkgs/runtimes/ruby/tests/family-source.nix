# Pure whole-family source contract. Never realizes a package or its tests.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  contains = needle: text: lib.hasInfix (builtins.unsafeDiscardStringContext needle) text;
  step = name: p: lib.findFirst (s: s.name == name) (throw "missing step ${name}") p.buildSteps;
  families = name: lib.hasPrefix "ruby_" name || lib.hasPrefix "bundler_" name;
  canonical = lib.filterAttrs (name: _: families name) tvp.canonical;
  variants = lib.mapAttrs (_: lib.filterAttrs (name: _: families name)) tvp.variants;
  inventory = tvp.lib.recipeSplits.inventory { inherit canonical variants; };
  all =
    builtins.attrValues canonical
    ++ lib.concatMap builtins.attrValues (builtins.attrValues variants);
  candidate = import ../../../../bases/source-gnu { };
  checks =
    p:
    let
      s = p.specification;
      ruby = p.pname == "ruby";
      changed = p.editRuntime (
        r: r // (if ruby then { zlib = tvp.packages.zlib_1_3_1; } else { ruby = tvp.packages.ruby_4; })
      );
      disabled = if ruby then p.override { doCheck = false; } else p;
      coreutils = p.edit (
        s:
        s
        // {
          coreutils = candidate.tools.coreutils // {
            outPath = "/nix/store/00000000000000000000000000000000-coreutils-edit";
          };
        }
      );
      compiler = p.edit (s: s // { base = candidate.base; });
      source = p.override { src = builtins.toFile "ruby-bundler-source-edit" "source-only"; };
      library =
        if ruby then
          p.edit (
            s:
            s
            // {
              libraries = s.libraries // {
                zlib = tvp.packages.zlib_1_3_1;
              };
            }
          )
        else
          p.edit (s: s // { ruby = tvp.packages.ruby_4; });
      factory =
        (import (if ruby then ../. else ../../../build-tools/bundler) { inherit pkgs tvp; })
        .recipes.${p.pname};
      retained =
        (tvp.lib.packages.mkVersions factory.constructionRecipe)
        .${tvp.lib.versions.attrName p.pname p.version};
      selected = pkgs // {
        inherit lib;
        runCommand = _: _: _: { callerSelected = true; };
      };
      expectedProvider = if ruby then changed.runtime.zlib else changed.runtime.ruby;
      declaredProvider = if ruby then changed.tvp.deps.zlib else changed.tvp.deps.ruby;
      test = if ruby then "zlib" else "ruby";
    in
    {
      noOp =
        (p.override { }).drvPath == p.drvPath
        && (p.edit (x: x)).drvPath == p.drvPath
        && (p.editRuntime (x: x)).drvPath == p.drvPath;
      unknownRejected =
        !(builtins.tryEval (p.override { unknownFamilyArgument = true; }).drvPath).success;
      outputs =
        p.outputs == [ "out" ]
        && p.out.drvPath == p.drvPath
        && (builtins.head p.all).drvPath == p.drvPath
        && p.out.artifact.drvPath == p.artifact.drvPath
        && (builtins.head p.all).artifact.drvPath == p.artifact.drvPath;
      equalWidth = !ruby || builtins.stringLength p.outPath == builtins.stringLength p.artifact.outPath;
      runtimeIsolation = changed.artifact.drvPath == p.artifact.drvPath && changed.drvPath != p.drvPath;
      metadata = declaredProvider.drvPath == expectedProvider.drvPath;
      reboundTests =
        changed.tests.${test}.drvPath != p.tests.${test}.drvPath
        && changed.out.tests.${test}.drvPath == changed.tests.${test}.drvPath
        && (builtins.head changed.all).tests.${test}.drvPath == changed.tests.${test}.drvPath;
      libraryEdit = library.artifact.drvPath != p.artifact.drvPath;
      coreutilsEdit =
        (coreutils.testContext.mkTest {
          package = coreutils;
          name = "coreutils-probe";
          script = "printf okay";
          expected = "okay";
        }).specification.coreutils.outPath == coreutils.specification.coreutils.outPath;
      compilerEdit = compiler.tvp.cc.drvPath == candidate.toolchain.driver.drvPath;
      sourceEdit = source.artifact.drvPath != p.artifact.drvPath && source.drvPath != p.drvPath;
      sourceOverrideEdit = source.drvPath == (p.edit (s: s // { src = source.src; })).drvPath;
      noProductionTests = builtins.all (
        x:
        !contains "test-basic" (x.run or "")
        && !contains "bootstraptest/runner" (x.run or "")
        && !contains "upstream.log" (x.run or "")
      ) p.buildSteps;
      upstreamIsolation =
        !ruby
        || (
          disabled.artifact.drvPath == p.artifact.drvPath
          && disabled.drvPath == p.drvPath
          && !(disabled.tests ? upstream-basic)
          && p.tests ? upstream-basic
        );
      upstreamConsumesFinal =
        !ruby || contains "${p}/bin/ruby" (builtins.head p.tests.upstream-basic.buildSteps).run;
      preservedFactory =
        (factory.extraArgs.mkTests.override { pkgs = selected; } retained).version.callerSelected
        && (factory.constructionRecipe.extraArgs.mkTests.override { pkgs = selected; } retained)
          .version.callerSelected;
      finalCoreutils = contains "${s.coreutils}/bin/cp" (step "output.copy-artifacts" p).run;
    };
  results = map (p: {
    name = "${p.pname}-${p.version}";
    checks = checks p;
  }) all;
  failed = builtins.filter (r: !(builtins.all (x: x) (builtins.attrValues r.checks))) results;
  reviewContracts = import ./review-contracts.nix { inherit pkgs tvp; };
in
assert builtins.length inventory.rows == 149;
assert builtins.all (r: r.compliant) inventory.rows;
assert failed == [ ] || throw "Ruby/Bundler family source contracts: ${builtins.toJSON failed}";
assert builtins.all (x: x) (builtins.attrValues reviewContracts);
{
  count = builtins.length inventory.rows;
  inherit results reviewContracts;
  qualification = "SOURCE_ONLY; all changed releases remain uncompiled and runtime-unqualified";
}
