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
      "libcups.install"
      "libcups.receipt"
    ])
  ) prefix;
  private = [
    (
      environment
      // {
        name = "libcups.test-patches";
        cwd = "source";
        tools = (environment.tools or [ ]) ++ [ d.patch ];
        run = builtins.concatStringsSep "\n" (
          map (p: "${d.patch}/bin/patch -p1 < '${p}'") (
            builtins.filter (p: builtins.elem p d.testPatches) d.patches
          )
        );
      }
    )
  ];
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
        (builtins.concatLists (
          map (s: [ s ] ++ (if s.name == "libcups.prepare" then private else [ ])) production
        ))
        ++ [
          (
            environment
            // {
              name = "libcups.check";
              cwd = "source";
              run = ''
                  export CUPS_TEST_BINDIR=${d.coreutils}/bin
                export CUPS_TEST_SEARCH_PATH=/nonexistent:${d.coreutils}/bin
                ${make} -C cups testarray testfile testhttp testipp testi18n testoptions testppd testpwg testraster
                  mkdir -p "$out"
                  printf upstream-pass > "$out/result"
              '';
            }
          )
        ];
    }
  )
