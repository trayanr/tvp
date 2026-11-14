# Pure tier and construction-input contracts. No model provider can be built.
{ lib, builder }:
let
  package =
    pname:
    (builtins.derivation {
      name = "tier-model-${pname}";
      system = "x86_64-linux";
      builder = "/never-build-a-tier-model";
    })
    // {
      inherit pname;
    };
  raw = package "gcc";
  libc = package "glibc";
  binutils = (package "binutils") // {
    suffixSalt = "x86_64_unknown_linux_gnu";
  };
  shell = package "bash";
  coreutils = package "coreutils";
  make = package "gnumake";
  tar = package "gnutar";
  patchelf = package "patchelf";
  compiler = (package "gcc-wrapper") // {
    bintools = binutils;
    inherit libc;
    cc = raw;
    defaultHardeningFlags = [ "pic" ];
    suffixSalt = "x86_64_unknown_linux_gnu";
  };
  legacy = {
    name = "earlier-gcc";
    builtBy = null;
    platform = {
      system = "x86_64-linux";
      config = "x86_64-unknown-linux-gnu";
      isMusl = false;
    };
    stdenv = {
      cc = compiler;
      initialPath = [
        shell
        coreutils
        make
        tar
      ];
      shell = "${shell}/bin/bash";
      defaultNativeBuildInputs = [
        ./base-tiers.nix
        patchelf
      ];
    };
  };
  tiers = import ../../bases/tiers { inherit lib builder; };
  inputs = tiers.fromLegacy legacy;
  seed = tiers.mkTier {
    name = "seed";
    compiler = inputs.compiler;
    inherit shell coreutils;
    standardTools = {
      gnumake = make;
      unused = throw "unused standard provider forced";
    };
  };
  nextCompiler = inputs.compiler // {
    outPath = (package "next-gcc").outPath;
    drvPath = (package "next-gcc").drvPath;
  };
  next = tiers.mkTier {
    name = "next";
    previous = seed // {
      compiler = throw "tier lineage forces prior providers";
    };
    compiler = nextCompiler;
    inherit shell coreutils;
  };
  edited = inputs.edit (args: args // { compiler = nextCompiler; });
  coreEdit = inputs.edit (args: args // { coreutils = package "other-coreutils"; });
  explicitTools = inputs.edit (
    args:
    args
    // {
      coreutils = package "other-coreutils";
      tools = [ make ];
    }
  );
  replacementPatchelf = package "selected-patchelf";
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  results = {
    sameCompilerProducer = inputs.compiler.drvPath == compiler.drvPath;
    sameBinutils = inputs.compiler.bintools.drvPath == binutils.drvPath;
    sameLibc = inputs.compiler.libc.drvPath == libc.drvPath;
    compilerRuntime =
      inputs.runtimeDirectories == [
        "${libc}/lib"
        "${raw}/lib"
      ];
    exactFloor = inputs.tools == legacy.stdenv.initialPath;
    exactShell = inputs.shell.drvPath == shell.drvPath;
    namedMake = inputs.standardTools.gnumake.drvPath == make.drvPath;
    namedTar = inputs.standardTools.gnutar.drvPath == tar.drvPath;
    existingFixup = inputs.standardTools.patchelf.drvPath == patchelf.drvPath;
    preferredFixup =
      (tiers.fromLegacy (
        legacy
        // {
          fixupTools.patchelf = replacementPatchelf;
        }
      )).standardTools.patchelf.drvPath == replacementPatchelf.drvPath;
    noPublicToolLookup = !(inputs.standardTools ? python);
    ownedInterface = !(inputs ? stdenv) && !(inputs ? mkDerivation);
    adaptationRecorded =
      inputs.construction == {
        kind = "legacy-inputs";
        previous = null;
        sourceBase = legacy.name;
      };
    seedBoundary = seed.construction.kind == "seed" && seed.construction.previous == null;
    tierLineage = next.construction.kind == "stage" && next.construction.previous == seed.name;
    minimalFloor = map (p: p.drvPath) seed.tools == [ coreutils.drvPath ];
    currentCompiler = (next.environment { }).env.CC == "${nextCompiler}/bin/cc";
    baseEditRebinds = (edited.environment { }).env.CC == "${nextCompiler}/bin/cc";
    baseEditProvenance = edited.construction == inputs.construction;
    editCoreutilsFloor =
      builtins.any (p: p.drvPath == (package "other-coreutils").drvPath) coreEdit.tools
      && !(builtins.any (p: p.drvPath == coreutils.drvPath) coreEdit.tools);
    explicitEditTools = explicitTools.tools == [ make ];
    shellOverrideFloor =
      !(builtins.elem shell.drvPath (
        map (p: p.drvPath) (inputs.override { shell = package "new-shell"; }).tools
      ));
    shellEditFloor = builtins.elem (package "new-shell").drvPath (
      map (p: p.drvPath) (inputs.edit (args: args // { shell = package "new-shell"; })).tools
    );
    partialToolOverride =
      (inputs.override {
        standardTools.gnumake = package "other-make";
      }).standardTools.gnutar.drvPath == tar.drvPath;
    adaptedIdempotent = (tiers.fromLegacy inputs).name == inputs.name;
    invalidLegacy = rejects (tiers.fromLegacy { name = "missing"; });
    missingFloor = rejects (
      tiers.fromLegacy (
        legacy
        // {
          stdenv = legacy.stdenv // {
            initialPath = [ make ];
          };
        }
      )
    );
    invalidEdit = rejects (inputs.edit (args: args // { compiler = null; }));
    selfLineage = rejects (
      tiers.mkTier {
        name = "seed";
        previous = seed;
        compiler = inputs.compiler;
        inherit shell coreutils;
      }
    );
    invalidConstruction = rejects (inputs.override { construction.kind = "unknown"; });
    missingPreviousStage = rejects (
      inputs.override {
        construction = {
          kind = "stage";
          previous = null;
        };
      }
    );
    noncompactProvenance = rejects (
      inputs.override {
        construction = inputs.construction // {
          providers = [ compiler ];
        };
      }
    );
    contextualLineage = rejects (
      inputs.override {
        construction = {
          kind = "stage";
          previous = (package "hidden-previous").outPath;
        };
      }
    );
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "Base tier contracts: ${lib.concatStringsSep ", " failed}";
results
