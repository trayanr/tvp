# Private upstream validation. No validation producer feeds the installed artifact.
{
  package,
  lib,
  context,
}:
let
  d = package.specification;
  tools = (package.specification.base.standardTools or { }) // {
    binutils = package.specification.base.compiler.bintools;
  };

  steps = import ../../../../lib/build-steps.nix;
  environment = d.base.environment d.environment;
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${d.bash}/bin/bash'';
  prefix = (steps.partition package.buildSteps).first;
  production = builtins.filter (
    s:
    !(builtins.elem s.name [
      "alsa-lib.install"
      "alsa-lib.receipt"
    ])
  ) prefix;
  private = production;
in
(context.mkTest {
  inherit package;
  name = "upstream";
  script = "printf upstream-pass";
  expected = "upstream-pass";
}).edit
  (
    s:
    s
    // {
      outputs = d.outputs;
      plan = (private) ++ [
        (
          environment
          // {
            name = "alsa-lib.check";
            cwd = "source";
            run = ''
              ${make} check
              mkdir -p "$out"
              printf upstream-pass > "$out/result"
            '';
          }
        )
      ];
    }
  )
