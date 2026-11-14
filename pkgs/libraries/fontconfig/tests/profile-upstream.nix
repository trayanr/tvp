# Raw upstream execution and its acceptance are independent of production A/F.
{ package }:
let
  d = package.specification;
  steps = import ../../../../lib/build-steps.nix;
  prefix = builtins.filter (
    s:
    !(builtins.elem s.name [
      "fontconfig.install"
      "fontconfig.receipt"
    ])
  ) (steps.partition package.buildSteps).first;
  raw =
    (package.edit (
      s:
      (removeAttrs s [ "artifactName" ])
      // {
        pname = "fontconfig-profile-upstream-raw";
        runtime = { };
      }
    )).editSteps
      (
        _:
        prefix
        ++ [
          (
            (d.base.environment d.environment)
            // {
              name = "fontconfig.upstream-capture";
              cwd = "source";
              run = ''
                mkdir -p "$out"
                status=0
                ${d.meson}/bin/meson test -C build --print-errorlogs > "$out/log" 2>&1 || status=$?
                printf '%s\n' "$status" > "$out/exit-status"
                cp -r build/meson-logs "$out/meson-logs"
                cat "$out/log"
              '';
            }
          )
        ]
      );
  accepted = package.testContext.mkTest {
    inherit package;
    name = "upstream";
    tools = [ d.coreutils ];
    script =
      if !d.doCheck then
        "printf disabled"
      else
        ''
          cat ${raw}/log >&2
          test "$(cat ${raw}/exit-status)" = 0
          printf upstream-pass
        '';
    expected = if d.doCheck then "upstream-pass" else "disabled";
  };
in
accepted
// {
  passthru = accepted.passthru // {
    raw = if d.doCheck then raw else null;
  };
}
