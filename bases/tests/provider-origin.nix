# Evaluation-only production-provider gate. Nixpkgs' pure lib/config values are
# allowed; selecting its executable packages or adapting its stdenv is not.
{
  lib,
  tvp,
  sourceFiles ? [
    ../default.nix
    ../consumer.nix
    ../retained.nix
    ../compatibility.nix
    ../source-compiler.nix
    ../source-gcc13.nix
    ../gcc-4.9.4.nix
    ../gcc-9.5.0.nix
    ../gcc-13.3.0.nix
    ../gcc-16.2.0.nix
    ../source-gnu/default.nix
    ../source-gnu/hardening/default.nix
    ../source-gnu/inputs.nix
    ../tiers/source-gnu.nix
    ../../pkgs/compilers/gcc/build-base-4.9.4.nix
    ../../pkgs/compilers/gcc/build-base-9.5.0.nix
    ../../pkgs/compilers/gcc/build-owned-13.3.0.nix
    ../../bootstrap/source-full-gcc-driver.nix
  ],
}:
let
  plain = builtins.unsafeDiscardStringContext;
  package = p: builtins.isAttrs p && p ? outPath && p ? drvPath;
  path = p: plain p.outPath;
  same = a: b: package a && package b && path a == path b;
  steps = import ../../lib/build-steps.nix;
  compilerOf = base: if base ? compiler then base.compiler else base.stdenv.cc;
  owned = p: package p && p ? specification && p ? stageInputs;
  productionInputs =
    p:
    let
      spec = p.specification;
      parts = steps.partition spec.plan;
      commands = steps.active (parts.first ++ parts.second);
    in
    [
      spec.bash
      spec.coreutils
      (compilerOf spec.base)
    ]
    ++ (spec.base.baselineTools or spec.base.stdenv.initialPath)
    ++ lib.concatMap (step: step.tools ++ step.libraries) commands
    ++ builtins.attrValues (
      lib.filterAttrs (name: value: name != "src" && name != "source" && package value) (
        p.tvp.deps or { }
      )
    );

  # This independent import cannot follow a replaced public base or catalogue.
  source = import ../source-gnu { };
  sourceCompiler = import ../../bootstrap/source-full-gcc.nix { };
  sourceStages = import ../tiers/source-gnu.nix {
    inherit lib;
    builder = tvp.builder;
  };
  stages = builtins.attrValues sourceStages;
  trustedProviders =
    lib.concatMap (
      base:
      builtins.attrValues base.tools
      ++ base.baselineTools
      ++ base.referencePackages
      ++ [
        base.compiler
        base.compiler.bintools
        base.compiler.libc
      ]
    ) stages
    ++ builtins.attrValues source.tools
    ++ [ sourceCompiler.file ]
    ++ productionInputs sourceCompiler.compiler;
  trustedPaths = lib.unique (
    lib.concatMap (
      p: [ (path p) ] ++ map (output: path p.${output}) (p.outputs or [ "out" ])
    ) trustedProviders
  );
  sourceDrivers = map (base: path base.compiler) stages;
  ownedLib = import ../../bootstrap/owned-lib.nix { system = source.base.platform.system; };
  independentCatalogue = import ../. {
    inherit (source.base.platform) system;
    lib = ownedLib;
    builder = import ../../lib/builder.nix { lib = ownedLib; };
  };
  standaloneCatalogue = builtins.deepSeq (map
    (name: independentCatalogue.${name}.full.compiler.drvPath)
    [
      "gcc_4"
      "gcc_9"
      "gcc_13"
      "gcc_16"
    ]
  ) true;
  sameProducer =
    a: b:
    lib.isDerivation a
    && lib.isDerivation b
    && a.drvPath == b.drvPath
    && a.outPath == b.outPath
    && builtins.getContext a.drvPath == builtins.getContext b.drvPath
    && builtins.getContext a.outPath == builtins.getContext b.outPath;
  underlyingDriver =
    driver:
    if !(driver ? underlyingDriver) then
      driver
    else
      assert
        owned driver
        && driver ? hardeningPolicy
        && sameProducer driver.specification.driver driver.underlyingDriver
        && sameProducer driver.tvp.declaredDependencies.driver driver.underlyingDriver
        && driver.version == driver.underlyingDriver.version;
      underlyingDriver driver.underlyingDriver;
  underlyingBintools =
    bintools:
    if !(bintools ? underlyingBintools) then
      bintools
    else
      assert
        owned bintools
        && bintools ? hardeningPolicy
        && sameProducer bintools.specification.bintools bintools.underlyingBintools
        && sameProducer bintools.tvp.declaredDependencies.bintools bintools.underlyingBintools;
      underlyingBintools bintools.underlyingBintools;
  # The pure helper library is part of lowering. Retained source producers use
  # ownedLib; catalogue instantiation can use the supplied pure lib. In either
  # case the exposed A/F must match an actual fresh lowering, including contexts.
  splitProducer =
    raw:
    if !owned raw || !(raw ? artifact) || raw.outputs != [ "out" ] then
      false
    else
      let
        parts = steps.partition raw.specification.plan;
        exact =
          loweringLib:
          let
            expected = (import ../../lib/owned-build.nix { lib = loweringLib; }) raw.specification;
          in
          sameProducer raw expected
          && sameProducer raw.artifact expected.artifact
          && raw.drvPath != raw.artifact.drvPath;
      in
      parts.split
      && steps.active parts.first != [ ]
      && steps.active parts.second != [ ]
      && (exact ownedLib || exact lib);
  families = lib.filterAttrs (
    name: _: builtins.match "gcc_[0-9]+_[0-9]+_[0-9]+" name != null
  ) tvp.bases;
  rawCompiler = family: (underlyingDriver family.full.compiler).tvp.deps.compiler or null;
  selectedDrivers = map (family: path family.full.compiler) (builtins.attrValues families);
  constructionDrivers = map (family: path (underlyingDriver family.full.compiler)) (
    builtins.attrValues families
  );
  rows = lib.mapAttrs (
    name: family:
    let
      full = family.full;
      raw = rawCompiler family;
      driver = underlyingDriver full.compiler;
      ordinaryFloor = builtins.removeAttrs full.tools [ "gcc" ];
      expectedRuntime =
        if package raw then
          [
            "${full.compiler.libc}/lib"
            "${raw}/lib/gcc/${full.platform.config}/${raw.version}"
            "${raw}/lib"
          ]
        else
          [ ];
    in
    {
      ownedCompiler = splitProducer raw;
      sourcePredecessor =
        owned raw && builtins.elem (path (compilerOf raw.specification.base)) sourceDrivers;
      sourceShell = same full.shell source.base.shell;
      sourceCoreutils = same full.coreutils source.base.coreutils;
      sourceBinutils = same (underlyingBintools full.compiler.bintools) source.base.compiler.bintools;
      sourceLibc = same full.compiler.libc source.base.compiler.libc;
      nativeSysroot =
        package raw
        && builtins.elem "--with-sysroot=${full.compiler.libc}" raw.specification.configureFlags;
      nativeHeaderRoot =
        package raw
        && builtins.elem "--with-native-system-header-dir=/include" raw.specification.configureFlags;
      sourceFloor = map path full.baselineTools == map path source.base.baselineTools;
      namedFloor = lib.all (
        role:
        !(source.base.tools ? ${role})
        || same (
          if role == "binutils" then underlyingBintools ordinaryFloor.${role} else ordinaryFloor.${role}
        ) source.base.tools.${role}
      ) (builtins.attrNames ordinaryFloor);
      runtimeProviders = full.compiler.runtimeDirectories == expectedRuntime;
      runtimeLibc = package raw && same driver.tvp.deps.libc full.compiler.libc;
      consumerPolicy =
        full.compiler.defaultHardeningFlags == [
          "bindnow"
          "relro"
        ];
      compilerVersion = full.compiler.version == driver.version;
    }
  ) families;
  # Only active production tools/libraries are traversed. Optional upstream
  # harnesses are independent consumers and cannot contaminate this result.
  walk =
    seen: pending:
    if pending == [ ] then
      {
        inherit seen;
        foreign = [ ];
      }
    else
      let
        p = builtins.head pending;
        rest = builtins.tail pending;
        key = if package p then path p else "<invalid-provider>";
        known = builtins.hasAttr key seen || builtins.elem key trustedPaths;
        allowed =
          known
          || (
            owned p
            && builtins.elem (path (compilerOf p.specification.base)) (
              sourceDrivers ++ selectedDrivers ++ constructionDrivers
            )
          );
        result = walk (seen // { ${key} = true; }) (
          (lib.optionals (!known && allowed) (productionInputs p)) ++ rest
        );
      in
      result // { foreign = lib.optional (!allowed) key ++ result.foreign; };
  contexts = lib.concatMap (
    family:
    builtins.attrValues (
      lib.filterAttrs (
        _: value: builtins.isAttrs value && value ? tools && value ? compiler && value ? baselineTools
      ) family
    )
  ) (builtins.attrValues families);
  initial =
    lib.concatMap (base: builtins.attrValues base.tools ++ base.baselineTools) contexts
    ++ map rawCompiler (builtins.attrValues families);
  closure = walk { } initial;

  # A small lexical guard complements physical-provider checks; it is not a
  # whole-repository Nix parser or a substitute for execution qualification.
  captures = pattern: text: builtins.filter builtins.isList (builtins.split pattern text);
  scan =
    file:
    let
      code = lib.concatStringsSep "\n" (
        builtins.filter (line: builtins.match "[[:space:]]*#.*" line == null) (
          lib.splitString "\n" (builtins.readFile file)
        )
      );
      attrs = map builtins.head (captures "pkgs\\.([A-Za-z0-9_-]+)" code);
      inherited = lib.concatMap (
        capture:
        builtins.filter (word: builtins.isString word && word != "") (
          builtins.split "[[:space:]]+" (builtins.head capture)
        )
      ) (captures "inherit[[:space:]]*\\([[:space:]]*pkgs[[:space:]]*\\)([^;]*);" code);
    in
    {
      file = plain (toString file);
      foreignSelections = builtins.filter (
        name:
        !(builtins.elem name [
          "lib"
          "config"
        ])
      ) (attrs ++ inherited);
      borrowedAdapter = lib.hasInfix "borrowed.nix" code || lib.hasInfix "borrowed-tools.nix" code;
    };
  sourceRows = map scan sourceFiles;
  badSources = builtins.filter (row: row.foreignSelections != [ ] || row.borrowedAdapter) sourceRows;
  badFamilies = lib.mapAttrs (
    _: checks: builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks)
  ) rows;
  failed = lib.filterAttrs (_: failures: failures != [ ]) badFamilies;
in
assert families != { } || throw "TVP provider origin: no exact compiler families registered";
assert
  badSources == [ ]
  || throw "TVP provider origin: foreign base source selections: ${builtins.toJSON badSources}";
assert
  failed == { }
  || throw "TVP provider origin: foreign or incomplete compiler providers: ${builtins.toJSON failed}";
assert
  closure.foreign == [ ]
  || throw "TVP provider origin: unregistered production providers: ${builtins.toJSON closure.foreign}";
{
  schema = "tvp.base-provider-origin/v1";
  scope = "Public compiler-family production providers and named active base source modules; no runtime qualification.";
  inherit rows sourceRows standaloneCatalogue;
  checkedProductionProviders = builtins.length (builtins.attrNames closure.seen);
}
