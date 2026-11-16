# Pure wiring checks: model tools are never realized.
{ lib }:
let
  builder = import ../builder.nix { inherit lib; };
  model =
    name:
    builtins.derivation {
      inherit name;
      system = "x86_64-linux";
      builder = "/never-build-shared-helper-model";
    };
  python = model "shared-helper-python";
  alternate = model "shared-helper-alternate-python";
  base = {
    tools = { inherit python; };
    environment = env: env // { selectedBase = "original"; };
  };
  other = base // {
    environment = env: env // { selectedBase = "edited"; };
  };
  context = builder.forBase base;
  command = context.steps.command {
    environment = {
      tools = [ python ];
      env.MARKER = "selected";
    };
  };
  step = command "package.build" "printf selected";
  restore = context.steps.restoreCheckpoint {
    name = "package.restore";
    checkpoint = "/checkpoint with spaces";
  };
  owned = (import ../owned-tests.nix { inherit lib; }) {
    inherit builder;
    base = throw "unused fixture base must remain lazy";
    coreutils = throw "unused test tools must remain lazy";
  };
  capture =
    { recipe, args, ... }:
    let
      result = recipe args result;
    in
    result;
  fixtureBase = rec {
    tools = {
      gnutar = python;
      xz = python;
    };
    shell = python;
    coreutils = python;
    compiler.libc = python;
    environment = args: args;
    override = changes: fixtureBase // changes;
  };
  fixtureContext = (import ../tests.nix { inherit lib; }).fromPackage {
    builder = capture;
    package.specification = {
      base = fixtureBase;
      bash = alternate;
      coreutils = alternate;
      tools = {
        gnutar = alternate;
        xz = alternate;
      };
    };
  };
  locale = fixtureContext.fixtures.gnuLocale;
  results = {
    editableRecord =
      step.name == "package.build" && step.run == "printf selected" && step.cwd == "source";
    environmentRetained = step.tools == [ python ] && step.env.MARKER == "selected";
    selectedBase = step.selectedBase == "original";
    explicitBaseWins =
      (context.steps.command {
        base = other;
        environment = { };
      } "test" ":").selectedBase == "edited";
    reboundBase =
      ((builder.forBase other).steps.command { environment = { }; } "test" ":").selectedBase == "edited";
    selectedCwd =
      (context.steps.command {
        environment = { };
        cwd = "build";
      } "test" ":").cwd == "build";
    callerEdit = (step // { enabled = false; }).enabled == false;
    restoreProvider = restore.tools == [ context.tools.python ];
    restoreQuoted = lib.hasInfix "'/checkpoint with spaces'" restore.run;
    restoreOverride =
      (context.steps.restoreCheckpoint {
        name = "test";
        checkpoint = "/checkpoint";
        python = alternate;
      }).tools == [ alternate ];
    fixturesLazy =
      builtins.attrNames owned.fixtures == [
        "alternateSource"
        "gnuLocale"
        "sentinel"
      ];
    fixtureEffectiveShell = locale.bash == alternate;
    fixtureEffectiveCoreutils = locale.coreutils == alternate;
    fixtureEffectiveTools =
      (builtins.head locale.plan).tools == [
        alternate
        alternate
        python
      ];
  };
in
assert
  builtins.all (value: value) (builtins.attrValues results)
  || throw "TVP shared helper contracts failed";
results
