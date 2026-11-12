# Private upstream validation. No validation producer feeds the installed artifact.
{ package }:
let
  d = package.specification;
  steps = import ../../../../lib/build-steps.nix;
  environment = d.base.environment d.environment;
  make = ''${d.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${d.bash}/bin/bash'';
  prefix = (steps.partition package.buildSteps).first;
  production = builtins.filter (
    s:
    !(builtins.elem s.name [
      "libxtst.install"
      "libxtst.receipt"
    ])
  ) prefix;
  private = production;
in
(package.testContext.mkTest {
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
      plan =
        if d.doCheck then
          (private)
          ++ [
            (
              environment
              // {
                name = "libxtst.check";
                cwd = "source";
                run = ''
                  ${make} check
                  mkdir -p "$out"
                  printf upstream-pass > "$out/result"
                '';
              }
            )
          ]
        else
          [
            {
              name = "libxtst.check-disabled";
              run = ''mkdir -p "$out"; printf disabled > "$out/result"'';
            }
          ];
    }
  )
