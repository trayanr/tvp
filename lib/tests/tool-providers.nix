# Pure metadata contracts. The model providers must never be built.
{ lib }:
let
  builder = import ../builder.nix { inherit lib; };
  package =
    name:
    builtins.derivation {
      inherit name;
      system = "x86_64-linux";
      builder = "/never-build-provider-model";
    };
  compiler = (package "provider-compiler") // {
    bintools = package "provider-binutils";
    libc = package "provider-libc";
    runtimeDirectories = [ "${package "provider-runtime"}/lib" ];
    defaultHardeningFlags = [ ];
  };
  make = package "first-make";
  otherMake = package "second-make";
  coreutils = package "provider-coreutils";
  otherCoreutils = package "other-coreutils";
  base = builder.base {
    name = "provider-model";
    platform = {
      system = "x86_64-linux";
      config = "x86_64-unknown-linux-gnu";
      isMusl = false;
    };
    inherit compiler coreutils;
    shell = package "provider-shell";
    tools = [ coreutils ];
    standardTools = {
      gnumake = make;
      unused = throw "unused base provider forced";
    };
  };
  context = builder.forBase base;
  api =
    (import ../default.nix {
      inherit lib;
      familyContext = {
        inherit builder base;
        helpers = {
          inherit lib;
          tvp = {
            inherit builder;
          };
        };
      };
    }).packages;
  defs = api.mkDefs {
    "1" = {
      builder = ./fixtures/implicit-tools-recipe.nix;
      deps.dependency = package "explicit-dependency";
    };
  };
  family = api.mkFamily {
    pname = "implicit-tools";
    versionTable = api.mkTable [
      {
        def = defs."1";
        releases."1" = "model";
      }
    ];
    source = _: builtins.toFile "implicit-tools-source" "source";
    tests = _: { };
  };
  p = (api.mkVersions family).implicit-tools_1;
  disabled = p.editSteps (
    builder.steps.insertBefore "model.finalize" [
      {
        name = "model.disabled";
        enabled = false;
        tools = throw "disabled tools forced";
        run = throw "disabled body forced";
      }
    ]
  );
  rebound = p.edit (s: s // { base = s.base.override { standardTools.gnumake = otherMake; }; });
  brokenBody = p.editSteps (
    builder.steps.replace "model.install" (
      step:
      step
      // {
        run = throw "command body forced while reading dependency metadata";
      }
    )
  );
  replaced = p.editSteps (
    builder.steps.replace "output.copy-artifacts" (
      _: context.outputs.copyArtifacts { coreutils = otherCoreutils; }
    )
  );
  anotherContext = builder.forBase (base.override { standardTools.gnumake = otherMake; });
  twoMakes = p.editSteps (
    builder.steps.insertBefore "model.finalize" [
      {
        name = "model.extra-make";
        tools = [ anotherContext.tools.gnumake ];
        run = ":";
      }
    ]
  );
  repeated = p.editSteps (
    builder.steps.insertBefore "model.finalize" [
      {
        name = "model.same-make";
        tools = [ context.tools.gnumake ];
        run = ":";
      }
    ]
  );
  gzip = package "helper-only-gzip";
  tar = package "helper-only-tar";
  unpack = p.editSteps (
    builder.steps.insertBefore "model.install" [
      (context.steps.unpack {
        src = p.src;
        inherit tar gzip;
        compression = "gzip";
        findutils = null;
      })
    ]
  );
  forRole =
    role: package:
    map (name: package.tvp.deps.${name}.drvPath) (
      builtins.filter (name: name == role || lib.hasPrefix "${role}#" name) (
        builtins.attrNames package.tvp.deps
      )
    );
  sorted = builtins.sort builtins.lessThan;
  results = {
    noManualProviderRecord = !(p.specification ? toolProviders);
    inferredOnlyUsedRoles =
      builtins.attrNames p.tvp.deps == [
        "bash"
        "coreutils"
        "dependency"
        "gnumake"
      ];
    makeProvider = p.tvp.deps.gnumake.drvPath == make.drvPath;
    explicitDependencyPreserved = p.tvp.deps.dependency.drvPath == defs."1".deps.dependency.drvPath;
    unusedBaseAndUpstreamStayLazy = builtins.isString p.drvPath;
    disabledInputsStayLazy =
      disabled.tvp.deps.gnumake.drvPath == make.drvPath && disabled.drvPath == p.drvPath;
    effectiveBaseEdit = rebound.tvp.deps.gnumake.drvPath == otherMake.drvPath;
    metadataDoesNotForceCommandBodies =
      brokenBody.tvp.deps.gnumake.drvPath == make.drvPath
      && !(builtins.tryEval brokenBody.drvPath).success;
    helperOverrideIsTracked =
      sorted (forRole "coreutils" replaced) == sorted [
        coreutils.drvPath
        otherCoreutils.drvPath
      ];
    helperOnlyProviderIsTracked =
      unpack.tvp.deps.gzip.drvPath == gzip.drvPath && unpack.tvp.deps.gnutar.drvPath == tar.drvPath;
    distinctProvidersRetained =
      sorted (forRole "gnumake" twoMakes) == sorted [
        make.drvPath
        otherMake.drvPath
      ];
    repeatedProviderDeduplicated = forRole "gnumake" repeated == [ make.drvPath ];
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "Tool provider contracts: ${lib.concatStringsSep ", " failed}";
results
