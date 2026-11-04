# Lower only stage-local prepared commands to the Nix primitive.
{ lib }:
spec:
let
  inherit (spec)
    pname
    version
    base
    bash
    coreutils
    plan
    ;
  outputNames =
    let
      names = import ./named-outputs.nix { inherit lib; } (spec.outputs or [ "out" ]);
      collisions = lib.intersectLists names (builtins.attrNames (spec.passthru or { }));
    in
    if names != [ "out" ] && collisions != [ ] then
      throw "TVP named outputs: output name collides with passthru metadata"
    else
      names;
  multiOutput = outputNames != [ "out" ];
  steps = import ./build-steps.nix;
  parts = steps.partition plan;
  stage =
    name: commands: artifact:
    let
      selected = steps.active commands;
      runner =
        import ./build-step-runner.nix
          {
            inherit
              lib
              base
              bash
              coreutils
              ;
          }
          {
            plan = map (
              step:
              step
              // {
                tools = lib.unique (step.tools ++ base.stdenv.initialPath);
                run =
                  ''
                    export NIX_HARDENING_ENABLE=${lib.escapeShellArg (lib.concatStringsSep " " base.stdenv.cc.defaultHardeningFlags)}
                    export SOURCE_DATE_EPOCH=315532800
                    if [[ -e "$TVP_SOURCE_ROOT/source-date-epoch" ]]; then
                      SOURCE_DATE_EPOCH=$(cat "$TVP_SOURCE_ROOT/source-date-epoch")
                    fi
                    ${lib.optionalString (artifact != null)
                      ''readonly TVP_ARTIFACT_ROOT=${lib.escapeShellArg (toString artifact)}; export TVP_ARTIFACT_ROOT''
                    }
                  ''
                  + step.run;
              }
            ) selected;
            temporaryDirectories = true;
            owned = true;
            outputs = outputNames;
          };
      drv = builtins.derivation (
        {
          inherit name;
          __structuredAttrs = true;
          stageInputs = map toString runner.inputs;
          inherit (base.platform) system;
          builder = "${bash}/bin/bash";
          args = [
            "-euc"
            ''
              source "$NIX_ATTRS_SH_FILE"
              ${
                if multiOutput then
                  lib.concatMapStringsSep "\n" (name: ''export ${name}="''${outputs[${name}]}"'') outputNames
                else
                  ''export out="''${outputs[out]}"''
              }
              export NIX_BUILD_TOP="$PWD"
              ${coreutils}/bin/mkdir workspace
              ${bash}/bin/bash ${runner.script} "$PWD/workspace"
            ''
          ];
          outputs = outputNames;
        }
        // lib.optionalAttrs (artifact != null) {
          # Native Nix output checks; never introduce a reference merely to test it.
          outputChecks.out.disallowedReferences = [ artifact ];
        }
      );
    in
    drv // { buildStepRunner = runner; };
  artifact = stage "${pname}-${version}-artifacts" parts.first null;
  package =
    if parts.split then
      stage "${pname}-${version}" parts.second artifact
    else
      stage "${pname}-${version}" parts.first null;
  exports = lib.concatMap (s: s.developmentLibraries or [ ]) (
    steps.active (parts.first ++ parts.second)
  );
in
assert
  !(multiOutput && parts.split)
  || throw "TVP named outputs: split with multiple outputs is not supported";
package
// {
  inherit pname version;
  inherit (spec) src;
  stdenv = base.stdenv;
  meta = spec.meta or { };
  tvp = spec.tvp or { };
  runtime = spec.runtime or { };
  development = (spec.development or { }) // {
    libraries = lib.unique exports;
  };
  buildEnvironment = spec.buildEnvironment or (_: { });
  passthru = spec.passthru or { };
}
// lib.optionalAttrs parts.split { artifact = artifact; }
