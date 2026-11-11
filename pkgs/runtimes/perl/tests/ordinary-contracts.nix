# Pure effective-spec controls: no extra Perl prefix variants are realized.
{ pkgs, tvp }:
let
  names = [
    "perl_5_24_4"
    "perl_5_28_3"
    "perl_5_30_3"
    "perl_5_32_1"
    "perl_5_34_3"
    "perl_5_36_3"
    "perl_5_38_5"
    "perl_5_40_5"
    "perl_5_42_3"
  ];
  candidate = import ../../../../bases/source-gnu { };
  alternateBase = candidate.withHardening { enable = [ "relro" ]; };
  controls =
    name:
    let
      p = tvp.canonical.${name};
      noop = p.edit (s: s);
      runtime = p.editRuntime (r: r // { dlopenDirectories = [ "${candidate.tools.coreutils}/lib" ]; });
      helper = p.edit (
        s:
        s
        // {
          finalizeHelper = builtins.toFile "perl-finalizer-control.py" (
            builtins.readFile s.finalizeHelper + "\n# final-only control\n"
          );
        }
      );
      finalStep = p.editSteps (
        plan:
        plan
        ++ [
          {
            name = "perl.control-final";
            run = "true";
          }
        ]
      );
      configure = p.edit (s: s // { configureFlags = s.configureFlags ++ [ "-Dusethreads" ]; });
      source = p.override { src = tvp.canonical.perl_5_44_0.src; };
      compiler = p.override { base = alternateBase; };
      libraries = p.edit (
        s:
        s
        // {
          environment = s.environment // {
            libraries = [ tvp.packages.zlib ];
          };
        }
      );
      tool = p.override { gnumake = tvp.packages.gnumake; };
      toolEdit = p.edit (s: s // { gnumake = tvp.packages.gnumake; });
      factory = tvp.lib.packages.mkVersions (
        builtins.removeAttrs ((import ../default.nix { inherit pkgs tvp; }).recipes.perl) [
          "constructionRecipe"
        ]
      );
      callerFactory =
        (import ../default.nix {
          pkgs = pkgs // {
            runCommand = throw "ambient runCommand used";
          };
          inherit tvp;
        }).canonical;
      flags = p.edit (
        s:
        s
        // {
          environment = s.environment // {
            overrides.flags.NIX_CFLAGS_COMPILE = [ "-O1" ];
          };
        }
      );
      paths = value: {
        drv = value.drvPath;
        artifact = value.artifact.drvPath;
      };
    in
    {
      noop = noop.drvPath == p.drvPath;
      overrideNoop = (p.override { }).drvPath == p.drvPath;
      editStepsNoop = (p.editSteps (plan: plan)).drvPath == p.drvPath;
      runtimeReusesArtifact =
        runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
      finalStepReusesArtifact =
        finalStep.artifact.drvPath == p.artifact.drvPath && finalStep.drvPath != p.drvPath;
      finalizerHelperReusesArtifact =
        helper.artifact.drvPath == p.artifact.drvPath && helper.drvPath != p.drvPath;
      sourceChangesArtifact = source.artifact.drvPath != p.artifact.drvPath;
      compilerChangesArtifact = compiler.artifact.drvPath != p.artifact.drvPath;
      configureChangesArtifact = configure.artifact.drvPath != p.artifact.drvPath;
      buildLibraryChangesArtifact = libraries.artifact.drvPath != p.artifact.drvPath;
      overrideToolChangesArtifact = tool.artifact.drvPath != p.artifact.drvPath;
      editToolChangesArtifact = toolEdit.artifact.drvPath != p.artifact.drvPath;
      factoryIdentity = factory.${name}.drvPath == p.drvPath;
      callerPkgsFactory = callerFactory.${name}.tests.version.drvPath == p.tests.version.drvPath;
      flagsChangeArtifact = flags.artifact.drvPath != p.artifact.drvPath;
      explicitTestRebind =
        (p.tests.version.override {
          package = runtime;
          libraries = [ runtime ];
        }).drvPath == runtime.tests.version.drvPath;
      testRebind = runtime.tests.version.drvPath != p.tests.version.drvPath;
      equalPrefixWidths = builtins.stringLength p.outPath == builtins.stringLength p.artifact.outPath;
      distinctProducers = p.drvPath != p.artifact.drvPath && p.outPath != p.artifact.outPath;
      identities = {
        default = paths p;
        inherit (runtime) drvPath;
        finalStep = paths finalStep;
      };
    };
in
builtins.listToAttrs (
  map (name: {
    inherit name;
    value = controls name;
  }) names
)
