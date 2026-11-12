# Reconfigure and build in a separate validation derivation. Production never
# depends on this check, its raw status or acceptance. Keep raw failures intact.
{ package }:
let
  s = package.specification;
  prefix =
    (builtins.foldl'
      (acc: step: {
        stop = acc.stop || step.name == "readline.install";
        plan = acc.plan ++ (if acc.stop || step.name == "readline.install" then [ ] else [ step ]);
      })
      {
        stop = false;
        plan = [ ];
      }
      s.plan
    ).plan;
  raw =
    (package.edit (
      spec:
      spec
      // {
        pname = "readline-upstream-raw";
        runtime = { };
      }
    )).editSteps
      (
        _:
        prefix
        ++ [
          (
            (s.base.environment s.environment)
            // {
              name = "readline.upstream-capture";
              cwd = "source";
              run = ''
                mkdir -p "$out"
                status=0
                ${s.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${s.bash}/bin/bash SHLIB_LIBS=-lncursesw check > "$out/log" 2>&1 || status=$?
                printf '%s\n' "$status" > "$out/exit-status"
                cat "$out/log"
              '';
            }
          )
        ]
      );
in
package.testContext.mkTest {
  inherit package;
  name = "upstream";
  tools = [ s.coreutils ];
  script = ''
    cat ${raw}/log >&2
    test "$(cat ${raw}/exit-status)" = 0
    echo upstream-ok
  '';
  expected = "upstream-ok";
}
