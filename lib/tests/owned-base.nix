# Pure semantic coverage: no selected package build or catalogue port.
{ lib, builder }:
let
  path = builtins.toFile "owned-base-model" "model data";
  package = name: {
    inherit name;
    outPath = path + "/${name}";
    system = "x86_64-linux";
  };
  compiler =
    name:
    (package name)
    // {
      bintools = package "${name}-binutils";
      libc = package "${name}-libc";
      libcTools = [ ];
      runtimeDirectories = [ "${path}/${name}/lib" ];
      defaultHardeningFlags = [ ];
    };
  a = compiler "a";
  b = compiler "b";
  args = {
    name = "model";
    platform = {
      system = "x86_64-linux";
      config = "x86_64-unknown-linux-gnu";
      isMusl = false;
    };
    compiler = a;
    shell = package "shell";
    tools = [ (package "coreutils") ];
  };
  base = builder.base args;
  rebound = base.override { compiler = b; };
  rejects = x: !(builtins.tryEval (builtins.deepSeq x true)).success;
  make =
    selected:
    builder {
      recipe =
        { }:
        final: {
          pname = "owned-base-model";
          version = "1";
          src = null;
          base = selected;
          bash = args.shell;
          coreutils = builtins.head args.tools;
          runtime.libraries = [ ];
          plan = [
            (
              (final.base.environment { })
              // {
                name = "model.probe";
                run = ":";
              }
            )
          ];
        };
      args = { };
      dependencyNames = [ ];
      metadata = { };
      selection.kind = "model";
      mkTests = _: { };
    };
  p = make base;
  namedBase = builder.base {
    inherit (args) name platform;
    tools = {
      gcc = a;
      bash = args.shell;
      coreutils = builtins.head args.tools;
      gnumake = package "make";
      unused = throw "unused catalogue provider was forced";
    };
    baselineTools = args.tools;
  };
  selectedDriver = namedBase.override { tools.gcc = b; };
  editedDriver = namedBase.edit (
    s:
    s
    // {
      tools = s.tools // {
        gcc = b;
      };
    }
  );
  contractCompiler = selected: {
    cc = (selected.environment { }).env.CC;
    cxx = (selected.environment { }).env.CXX;
    ar = (selected.environment { }).env.AR;
    runtime = selected.runtimeDirectories;
  };
  contracts = {
    enrichedBinutilsSurviveNoop =
      let
        selected = namedBase.override {
          tools.binutils = a.bintools // {
            buildEnvironment = _: { values.POLICY = "selected"; };
          };
        };
      in
      ((selected.override { }).tools.binutils.buildEnvironment { }).values.POLICY == "selected"
      && ((selected.edit (s: s)).tools.binutils.buildEnvironment { }).values.POLICY == "selected";
    enrichedBaselineSurvivesNoop =
      let
        selected = namedBase.override {
          baselineTools = [
            ((builtins.head args.tools) // { buildEnvironment = _: { values.POLICY = "kept"; }; })
          ];
        };
      in
      ((selected.override { }).environment { }).env.POLICY == "kept"
      && ((selected.edit (s: s)).environment { }).env.POLICY == "kept";
    editRemovesOptionalFields =
      let
        selected = namedBase.override {
          referencePackages = [ a ];
          construction.kind = "seed";
        };
        edited = selected.edit (
          s:
          builtins.removeAttrs s [
            "referencePackages"
            "construction"
          ]
        );
      in
      edited.referencePackages == [ ] && !(edited ? construction);
    editRemovesBaseline =
      (namedBase.edit (s: builtins.removeAttrs s [ "baselineTools" ])).baselineTools == [ ];
    editMissingRequiredRejected = rejects (namedBase.edit (s: builtins.removeAttrs s [ "platform" ]));
    explicitBinutilsRebindsWithDriver =
      let
        selected = namedBase.override { tools.binutils = a.bintools; };
      in
      (selected.edit (
        s:
        s
        // {
          tools = s.tools // {
            gcc = b;
          };
        }
      )).tools.binutils == b.bintools;
    fixedBaselineContributionsSurviveDriverEdit =
      let
        policyBase = namedBase.override {
          baselineTools = [ (a.bintools // { buildEnvironment = _: { values.LINK_POLICY = "kept"; }; }) ];
        };
      in
      ((policyBase.override { tools.gcc = b; }).environment { }).env.LINK_POLICY == "kept";
    namedCompiler = namedBase.tools.gcc == namedBase.compiler;
    derivedShell = namedBase.tools.bash == namedBase.shell;
    derivedBinutils = namedBase.tools.binutils == namedBase.compiler.bintools;
    derivedLibc = namedBase.libc == namedBase.compiler.libc;
    compatibilityIsDerived = namedBase.standardTools.gnumake == namedBase.tools.gnumake;
    lazyCatalogue = (namedBase.environment { }).env.CC == "${a}/bin/cc";
    unusedNotInEnvironment = !(builtins.elem (package "make") (namedBase.environment { }).tools);
    editAndOverrideAgree = contractCompiler selectedDriver == contractCompiler editedDriver;
    catalogueEditRebinds = contractCompiler selectedDriver == contractCompiler rebound;
    aliasEditRebinds =
      contractCompiler (namedBase.edit (s: s // { compiler = b; })) == contractCompiler selectedDriver;
    noOpBaseEdit = (make (namedBase.edit (s: s))).drvPath == (make namedBase).drvPath;
    unusedEditPreservesProducer =
      (make (namedBase.override { tools.unused = throw "unused override forced"; })).drvPath
      == (make namedBase).drvPath;
    namedCoreutilsRebindsBaseline =
      (namedBase.override { tools.coreutils = package "new-coreutils"; }).baselineTools
      == [ (package "new-coreutils") ];
    namedEditRebindsBaseline =
      (namedBase.edit (
        s:
        s
        // {
          tools = s.tools // {
            coreutils = package "new-coreutils";
          };
        }
      )).baselineTools == [ (package "new-coreutils") ];
    removingUnusedRole =
      !((namedBase.edit (s: s // { tools = builtins.removeAttrs s.tools [ "unused" ]; })).tools ? unused);
    partialBinutilsRejected = rejects (namedBase.override { tools.binutils = b.bintools; });
    partialLibcRejected = rejects (namedBase.override { libc = b.libc; });
    contradictoryDriverRejected = rejects (
      namedBase.override {
        compiler = a;
        tools.gcc = b;
      }
    );
    coherentDriverAndBinutils =
      (namedBase.override {
        tools.gcc = b;
        tools.binutils = b.bintools;
      }).compiler == b;
    unsupportedSystemRejected = rejects (
      namedBase.override {
        platform = args.platform // {
          system = "aarch64-linux";
        };
      }
    );

    direct =
      !(base ? stdenv)
      && !(base ? mkDerivation)
      && base.compiler == a
      && base.shell == args.shell
      && base.baselineTools == args.tools;
    runtimeFromCompiler = rebound.runtimeDirectories == b.runtimeDirectories;
    rebind =
      (rebound.environment { }).env.CC == "${b}/bin/cc"
      && (rebound.environment { }).env.CXX == "${b}/bin/c++"
      && (rebound.environment { }).env.AR == "${b.bintools}/bin/ar";
    noOldCompiler = !(builtins.elem a (rebound.environment { }).tools);
    shellPath = builtins.elem args.shell (base.environment { }).tools;
    baselineContribution =
      (base.override {
        tools = args.tools ++ [
          ((package "contributor") // { buildEnvironment = _: { values.EXPLICIT = "yes"; }; })
        ];
      }).environment
        { };
    explicitCC =
      (rebound.environment { overrides.values.CC = "/explicit/cc"; }).env.CC == "/explicit/cc";
    noop =
      (make (base.override { })).drvPath == p.drvPath
      && (p.override { }).drvPath == p.drvPath
      && (p.edit (s: s)).drvPath == p.drvPath
      && (p.editSteps (s: s)).drvPath == p.drvPath
      && (p.editRuntime (r: r)).drvPath == p.drvPath;
    provenance = p.tvp.cc == a && p.compiler == a && !(p ? stdenv) && !(p ? mkDerivation);
    reservedCompilerOutput = rejects (
      p.edit (
        s:
        s
        // {
          outputs = [
            "out"
            "compiler"
          ];
        }
      )
    );
    missing = rejects (base.override { compiler = null; });
    foreignShellSystem = rejects (
      base.override {
        shell = args.shell // {
          system = "aarch64-linux";
        };
      }
    );
    foreignShellHost = rejects (
      base.override {
        shell = args.shell // {
          hostPlatform.system = "aarch64-linux";
        };
      }
    );
    foreignToolSystem = rejects (
      base.override { tools = [ ((package "foreign") // { system = "aarch64-linux"; }) ]; }
    );
    foreignToolHost = rejects (
      base.override {
        tools = [ ((package "foreign") // { hostPlatform.config = "aarch64-unknown-linux-gnu"; }) ];
      }
    );
    toolTargetIsNotExecutionPlatform =
      (base.override {
        tools = [ ((package "cross-tool") // { targetPlatform.system = "aarch64-linux"; }) ];
      }).name == base.name;
    buildPlatformIsProvenance =
      (base.override {
        compiler = a // {
          buildPlatform.system = "aarch64-linux";
        };
      }).name == base.name;
    invalidHardening =
      builtins.all
        (
          flags:
          rejects (
            base.override {
              compiler = a // {
                defaultHardeningFlags = flags;
              };
            }
          )
        )
        [
          null
          "fortify"
          [
            "fortify"
            null
          ]
          1
          { }
        ];
    validHardening =
      (base.override {
        compiler = a // {
          defaultHardeningFlags = [
            "fortify"
            "pic"
          ];
        };
      }).name == base.name;
    platform = rejects (
      base.override {
        platform = args.platform // {
          isMusl = true;
        };
      }
    );
    contradiction = rejects (
      base.override {
        compiler = a // {
          targetPlatform.config = "aarch64-unknown-linux-gnu";
        };
      }
    );
    missingToolchain = rejects (base.override { compiler = builtins.removeAttrs a [ "bintools" ]; });
    invalidRuntime = rejects (
      base.override {
        compiler = a // {
          runtimeDirectories = [ "" ];
        };
      }
    );
    conflictingContribution = rejects (
      (base.environment {
        tools = [ ((package "conflict") // { buildEnvironment = _: { values.CC = "/conflict"; }; }) ];
      }).env
    );
  };
  results = contracts // {
    baselineContribution = contracts.baselineContribution.env.EXPLICIT == "yes";
  };
  failures = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failures == [ ] || throw "Owned base contracts: ${lib.concatStringsSep ", " failures}";
results
