# Pure compatibility controls: retained interfaces follow one owned selection.
# Model providers cannot be realized and no package catalogue is imported.
{ lib, builder }:
let
  platforms = import ../platforms.nix { inherit lib; };
  api = import ../bases.nix { inherit lib platforms; };
  tiers = import ../../bases/tiers { inherit lib builder; };
  package =
    pname: version:
    (builtins.derivation {
      name = "compatibility-model-${pname}-${version}";
      system = "x86_64-linux";
      builder = "/never-build-a-base-compatibility-model";
    })
    // {
      inherit pname version;
    };
  bash = package "bash" "5";
  coreutils = package "coreutils" "9";
  make = package "gnumake" "4";
  bintools = package "binutils" "2.42";
  libc = package "glibc" "2.39";
  gcc = (package "gcc-wrapper" "13.3.0") // {
    inherit bintools libc;
    runtimeDirectories = [ "${libc}/lib" ];
    libcTools = [ ];
    defaultHardeningFlags = [ ];
  };
  native = lib.systems.elaborate "x86_64-linux";
  selectedPlatform = platforms.mkNative {
    buildPlatform = native;
    hostPlatform = native;
    targetPlatform = native;
  };
  stdenv = {
    system = "x86_64-linux";
    buildPlatform = native;
    hostPlatform = native;
    targetPlatform = native;
    cc = gcc;
    initialPath = [
      coreutils
      bash
      make
    ];
    shell = "${bash}/bin/bash";
    # This symbol must remain untouched; bridge construction does not derive it.
    mkDerivation = value: value;
  };
  base = builder.base {
    name = "owned-gcc13";
    platform = selectedPlatform // {
      isMusl = false;
    };
    tools = {
      inherit bash coreutils;
      gcc = gcc;
      gnumake = make;
    };
    baselineTools = stdenv.initialPath;
  };
  args = {
    inherit base stdenv;
    name = "historic-gcc13";
    builtBy = "seed";
  };
  view = api.legacyEnvironment args;
  historical = {
    name = "historic-gcc13";
    cc = "13.3.0";
    binutils = "2.42";
    libc = "2.39";
    floor = [
      "coreutils"
      "bash"
      "gnumake"
    ];
    builtBy = "seed";
    inherit stdenv;
    platform = selectedPlatform;
  };
  oldEnvironment = import ../build-environment.nix {
    inherit lib;
    base = historical;
  };
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  results = {
    ownedDefinitionIsAuthoritative = view.ownedBase.compiler.outPath == base.tools.gcc.outPath;
    legacyViewHasNoOwnedDispatch = !(view ? compiler) && !(view ? tools) && !(view ? baselineTools);
    versionFields =
      view.cc == gcc.version && view.binutils == bintools.version && view.libc == libc.version;
    orderedFloor = view.floor == historical.floor;
    originalNameAndLineage = view.name == historical.name && view.builtBy == historical.builtBy;
    originalPlatform = view.platform == selectedPlatform;
    originalEnvironment =
      (view.environment { }).env == (oldEnvironment { }).env
      && map toString (view.environment { }).tools == map toString (oldEnvironment { }).tools;
    retainedStdenvMethod = (view.stdenv.mkDerivation { selected = true; }).selected;
    projectionUsesOwnedDefinition = (tiers.fromLegacy view).compiler.outPath == base.tools.gcc.outPath;
    projectionDoesNotRediscoverFloor =
      (tiers.fromLegacy (
        view // { stdenv = throw "the selected owned base must not rediscover stdenv"; }
      )).name == base.name;
    missingOwnedDefinition = rejects (api.legacyEnvironment (args // { base = historical; }));
    mismatchedCompiler = rejects (
      api.legacyEnvironment (
        args
        // {
          stdenv = stdenv // {
            cc = gcc // {
              outPath = (package "other-gcc" "13").outPath;
            };
          };
        }
      )
    );
    mismatchedBinutils = rejects (
      api.legacyEnvironment (
        args
        // {
          stdenv = stdenv // {
            cc = gcc // {
              bintools = package "other-binutils" "2";
            };
          };
        }
      )
    );
    mismatchedLibc = rejects (
      api.legacyEnvironment (
        args
        // {
          stdenv = stdenv // {
            cc = gcc // {
              libc = package "other-libc" "2";
            };
          };
        }
      )
    );
    reorderedFloor = rejects (
      api.legacyEnvironment (
        args
        // {
          stdenv = stdenv // {
            initialPath = [
              bash
              coreutils
              make
            ];
          };
        }
      )
    );
    mismatchedShell = rejects (
      api.legacyEnvironment (
        args
        // {
          stdenv = stdenv // {
            shell = "${package "other-bash" "5"}/bin/bash";
          };
        }
      )
    );
    mismatchedExecutionSystem = rejects (
      api.legacyEnvironment (
        args
        // {
          stdenv = stdenv // {
            system = "aarch64-linux";
          };
        }
      )
    );
    emptyName = rejects (api.legacyEnvironment (args // { name = ""; }));
    noOldConstructor = !(api ? mkBase);
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "Base compatibility: ${lib.concatStringsSep ", " failed}";
results
