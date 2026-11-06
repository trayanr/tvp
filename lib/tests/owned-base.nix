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
  contracts = {
    direct =
      !(base ? stdenv)
      && !(base ? mkDerivation)
      && base.compiler == a
      && base.shell == args.shell
      && base.tools == args.tools;
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
