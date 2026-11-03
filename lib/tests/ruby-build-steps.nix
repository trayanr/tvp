{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  p = tvp.variants.build-steps.ruby_4_0_6;
  steps = import ../build-steps.nix;
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  off = p.override {
    yjit = false;
    zjit = false;
    rustc = throw "disabled Rust forced";
  };
  one = p.override { yjit = false; };
  edited = p.editSteps (
    steps.insertAfter "ruby.build" [
      {
        name = "local.probe";
        run = ":";
      }
    ]
  );
  rebound = edited.override { zlib = tvp.packages.zlib_1_3_1; };
  replay = (p.override { zlib = tvp.packages.zlib_1_3_1; }).editSteps (
    steps.insertAfter "ruby.build" [
      {
        name = "local.probe";
        run = ":";
      }
    ]
  );
  coherent =
    value:
    value.tvp.jit == value.passthru.tvp.jit
    && value.tvp.deps.zlib.drvPath == value.passthru.tvp.deps.zlib.drvPath
    &&
      value.tvp.declaredDependencies.zlib.drvPath == value.passthru.tvp.declaredDependencies.zlib.drvPath
    && value.tests.gems.drvPath == value.passthru.tests.gems.drvPath
    && value.gemPath == value.passthru.gemPath
    && value.libDir == "4.0.0"
    && value.libPath == "lib/ruby/4.0.0"
    && value.rubyEngine == "ruby"
    && !value.baseRuby
    &&
      [
        value.majorVersion
        value.minorVersion
        value.teenyVersion
      ] == [
        "4"
        "0"
        "6"
      ]
    && value.patchLevel == null;
  bound = value: builtins.any (i: i.outPath == value.outPath) value.tests.gems.nativeBuildInputs;
  authority = import ../native-build.nix { inherit lib; } {
    pname = "passthru-authority-probe";
    version = "1";
    src = p.src;
    base = tvp.bases.default;
    inherit (tvp.packages) bash coreutils;
    plan = [ ];
    tvp.marker = true;
    runtime.libraries = [ ];
    passthru = {
      marker = "inert";
      tvp = throw "passthru overrides runner metadata";
      runtime = throw "passthru overrides runtime";
      buildStepRunner = throw "passthru overrides runner";
    };
  };
  contracts = {
    inventorySupport =
      builtins.length supportRows == builtins.length (builtins.attrNames supportInputs)
      && builtins.all (
        row:
        builtins.hasAttr row.dependency supportInputs
        && row.resolved.drv == supportInputs.${row.dependency}.drvPath
        && row.resolved.out == supportInputs.${row.dependency}.outPath
      ) supportRows;
    passthruAuthority =
      authority.marker == "inert"
      && authority.tvp.marker
      && authority.runtime.libraries == [ ]
      && authority.buildStepRunner.inputs == [ ];

    defaults =
      p.tvp.jit == {
        yjit = true;
        zjit = true;
      };
    independentJit =
      one.tvp.jit == {
        yjit = false;
        zjit = true;
      }
      && one.tvp.deps ? rustc;
    noRust =
      !(off.tvp.deps ? rustc)
      && !(off.tvp.declaredDependencies ? rustc)
      && builtins.isString off.drvPath
      && builtins.all (i: !(lib.hasPrefix "rustc" (i.pname or ""))) off.buildStepRunner.inputs;
    noJitTests = !(off.tests ? yjit) && !(off.tests ? zjit);
    activeToolsLazy = builtins.isString (
      lib.concatStrings (map (s: s.run) (steps.active off.buildSteps))
    );
    rootOutAll = builtins.all coherent (
      [
        p
        p.out
      ]
      ++ p.all
      ++ [
        off
        off.out
        rebound
        rebound.out
      ]
      ++ rebound.all
    );
    testRebinding =
      bound rebound
      && bound rebound.out
      && builtins.all bound rebound.all
      && rebound.tests.gems.drvPath != p.tests.gems.drvPath;
    replay = rebound.drvPath == replay.drvPath;
    selectedDependency = rebound.passthru.tvp.deps.zlib.drvPath == tvp.packages.zlib_1_3_1.drvPath;
    noOp = (p.override { }).drvPath == p.drvPath && (p.editSteps (x: x)).drvPath == p.drvPath;
    unknown = rejects (p.override { typo = true; }).drvPath;
    missing = rejects (p.editSteps (steps.delete "missing.step")).drvPath;
    duplicate =
      rejects
        (p.editSteps (
          steps.append [
            {
              name = "ruby.build";
              run = ":";
            }
          ]
        )).drvPath;
    noArchive = !(builtins.elem "output.strip-archives" (map (s: s.name) p.buildSteps));
    sixteenSharedTests =
      builtins.all (n: builtins.hasAttr n p.tests) (builtins.attrNames tvp.canonical.ruby_4_0_6.tests)
      && builtins.length (builtins.attrNames tvp.canonical.ruby_4_0_6.tests) == 16;
    independentConsumer = p.tvp.declaredTestDependencies.consumerCompiler.drvPath != p.tvp.cc.drvPath;
  };
  failed = builtins.filter (n: !contracts.${n}) (builtins.attrNames contracts);
  inherit (tvp.packages) gzip;
  python = tvp.packages.python_3;
  binutils = tvp.packages.binutils_2;
  patchelf = tvp.packages.patchelf_0;
  nativeTools = {
    inherit
      python
      binutils
      patchelf
      gzip
      ;
  };
  checkEnvironment = tvp.bases.default.stdenv;
  supportInputs = nativeTools // {
    environment = checkEnvironment;
    compiler = checkEnvironment.cc;
  };
  supportRows = builtins.filter (
    row: row.scope == "build-test-support" && row.consumer == "ruby-build-steps"
  ) tvp.dependencyInventory.support;
in
assert failed == [ ] || throw "Ruby step contracts: ${lib.concatStringsSep ", " failed}";
checkEnvironment.mkDerivation {
  name = "tvp-ruby-build-step-contracts";
  nativeBuildInputs = builtins.attrValues nativeTools;
  buildCommand = ''
    ${python}/bin/python3 -B ${./ruby-output.py} ${../elf-output.py} ${../native-output} ${../../pkgs/runtimes/ruby/compress-manuals.py} ${binutils} ${patchelf} ${gzip}/bin/gzip "$CC"
    printf '%s\n' '${builtins.toJSON contracts}' > "$out"
  '';
}
