# Private upstream validation. No validation producer feeds the installed artifact.
{ package }:
let
  d = package.specification;
  steps = import ../../../../lib/build-steps.nix;
  environment = d.base.environment d.environment;
  prefix = (steps.partition package.buildSteps).first;
  production = builtins.filter (
    s:
    !(builtins.elem s.name [
      "fontconfig.install"
      "fontconfig.receipt"
    ])
  ) prefix;
  private = map (
    s:
    if s.name == "fontconfig.configure" then
      s
      // {
        run = builtins.replaceStrings [ "-Dtests=disabled" ] [ "-Dtests=enabled" ] s.run;
      }
    else
      s
  ) production;
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
                name = "fontconfig.check";
                cwd = "source";
                run = ''
                  status=0
                  ${d.meson}/bin/meson test -C build --print-errorlogs || status=$?
                  cp -r build/meson-logs "$evidence/meson-logs"
                  test "$status" = 0
                  mkdir -p "$out"
                  printf upstream-pass > "$out/result"
                '';
              }
            )
          ]
        else
          [
            {
              name = "fontconfig.check-disabled";
              run = ''mkdir -p "$out" "$evidence"; printf disabled > "$out/result"'';
            }
          ];
    }
  )
