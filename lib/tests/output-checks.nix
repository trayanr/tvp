# Tiny installed trees exercise native Nix output checks without a compiler.
{
  lib,
  bash,
  coreutils,
}:
let
  lower = import ../owned-build.nix { inherit lib; };
  steps = import ../build-steps.nix;
  outputs = import ../native-output-steps.nix { inherit lib; };
  base = {
    platform.system = "x86_64-linux";
    shell = bash;
    tools = [ coreutils ];
    compiler.defaultHardeningFlags = [ ];
  };
  shapes = {
    singleSplit = {
      split = true;
      names = [ "out" ];
    };
    singleUnsplit = {
      split = false;
      names = [ "out" ];
    };
    namedSplit = {
      split = true;
      names = [
        "out"
        "evidence"
      ];
    };
    namedUnsplit = {
      split = false;
      names = [
        "out"
        "evidence"
      ];
    };
  };
  specs = lib.mapAttrs (name: shape: {
    pname = "output-check-${name}";
    version = "1";
    src = null;
    inherit base bash coreutils;
    outputs = shape.names;
    plan =
      [
        {
          name = "fixture.install";
          run = lib.concatMapStringsSep "\n" (output: ''
            mkdir -p "${"$" + output}"
            printf installed > "${"$" + output}/message"
          '') shape.names;
        }
      ]
      ++ lib.optionals shape.split [
        (steps.split "fixture.finalize")
        (outputs.copyArtifacts (
          { inherit coreutils; } // lib.optionalAttrs (shape.names != [ "out" ]) { outputs = shape.names; }
        ))
      ];
  }) shapes;
  checkedSpec =
    spec:
    spec
    // {
      outputChecks = lib.genAttrs spec.outputs (_: {
        maxSize = 100000;
        maxClosureSize = 1000000;
        disallowedReferences = [ bash ];
      });
    };
  fixtures = lib.mapAttrs (_: spec: lower (checkedSpec spec)) specs;
  perShape = lib.mapAttrs (
    name: spec:
    let
      p = fixtures.${name};
      changed = lower ((checkedSpec spec) // { outputChecks.out.maxSize = 2; });
      forbidden =
        if shapes.${name}.split then
          (if spec.outputs == [ "out" ] then [ p.artifact ] else map (n: p.artifact.${n}) spec.outputs)
        else
          [ ];
    in
    {
      callerChecks = builtins.all (
        output:
        p.outputChecks.${output}.maxSize == 100000
        && p.outputChecks.${output}.maxClosureSize == 1000000
        &&
          map toString p.outputChecks.${output}.disallowedReferences == map toString ([ bash ] ++ forbidden)
      ) spec.outputs;
      finalIdentityChanges = changed.drvPath != p.drvPath;
      artifactIsolation =
        !shapes.${name}.split
        || (p.artifact.drvPath == changed.artifact.drvPath && !(p.artifact ? outputChecks));
      omittedUnsplitChecks = shapes.${name}.split || !((lower spec) ? outputChecks);
    }
  ) specs;
  contracts = lib.concatMapAttrs (
    name: values: lib.mapAttrs' (key: value: lib.nameValuePair "${name}-${key}" value) values
  ) perShape;
  failures = lib.mapAttrs (_: spec: {
    size = lower ((checkedSpec spec) // { outputChecks.out.maxSize = 1; });
    reference = lower (
      (checkedSpec spec)
      // {
        # Let the reference ban itself reject the leaked shell, independently
        # of the positive fixture's deliberately small closure limit.
        outputChecks = lib.mapAttrs (_: checks: checks // { maxClosureSize = 1000000000; }) (
          (checkedSpec spec).outputChecks
        );
        plan = spec.plan ++ [
          {
            name = "fixture.forbidden-reference";
            run = ''printf '%s' '${bash}' > "$out/forbidden"'';
          }
        ];
      }
    );
  }) specs;
  failed = builtins.filter (name: !contracts.${name}) (builtins.attrNames contracts);
  check = builtins.derivation {
    name = "tvp-output-check-contracts";
    system = base.platform.system;
    builder = "${bash}/bin/bash";
    args = [
      "-euc"
      ''
        ${lib.concatMapStringsSep "\n" (
          name:
          lib.concatMapStringsSep "\n" (
            output: ''test "$(${coreutils}/bin/cat ${fixtures.${name}.${output}}/message)" = installed''
          ) shapes.${name}.names
        ) (builtins.attrNames shapes)}
        printf '%s\n' '${builtins.toJSON contracts}' > "$out"
      ''
    ];
  };
in
assert failed == [ ] || throw "Output-check contracts: ${lib.concatStringsSep ", " failed}";
check
// {
  passthru = {
    inherit contracts fixtures failures;
  };
}
