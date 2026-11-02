# One native output, explicit plan and retained base setup/fixup bridge.
{ lib }:
{
  pname,
  version,
  src,
  base,
  bash,
  coreutils,
  plan,
  runtime ? { },
  tvp ? { },
  meta ? { },
  passthru ? { },
}:
let
  steps = import ./build-steps.nix;
  selected = steps.active plan;
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
        temporaryDirectories = true;
        plan = map (
          step:
          step
          // {
            run =
              ''
                export NIX_HARDENING_ENABLE=${lib.escapeShellArg (lib.concatStringsSep " " base.stdenv.cc.defaultHardeningFlags)}
                if [[ -e "$TVP_SOURCE_ROOT/source-date-epoch" ]]; then
                  SOURCE_DATE_EPOCH=$(cat "$TVP_SOURCE_ROOT/source-date-epoch")
                  export SOURCE_DATE_EPOCH
                fi
              ''
              + step.run;
          }
        ) selected;
      };
in
base.stdenv.mkDerivation {
  inherit
    pname
    version
    src
    meta
    ;
  outputs = [ "out" ];
  buildCommand = ''
    mkdir workspace
    ${bash}/bin/bash ${runner.script} "$PWD/workspace"
  '';
  passthru = passthru // {
    inherit tvp runtime;
    buildStepRunner = runner;
  };
}
