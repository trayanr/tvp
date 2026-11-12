# Independent private upstream preparation/construction and raw execution.
# Production A/F never references this factory. Raw nonzero statuses stay raw.
{ package }:
let
  s = package.specification;
  steps = import ../../../../lib/build-steps.nix;
  prepared = builtins.filter (x: !(builtins.elem x.name ["nodejs.configure" "nodejs.build" "nodejs.install"]))
    (steps.partition package.buildSteps).first;
  environment = s.base.environment (s.environment // { tools = s.environment.tools; });
  enabled = s.doCheck or true;
  raw = (package.testContext.mkTest {
    inherit package;
    name = "upstream-raw";
    script = ":";
    expected = "";
  }).edit (spec: spec // {
    validationRole = "upstream-execution";
    plan = (if enabled then prepared else [ ]) ++ [
      (environment // {
        name = "nodejs.upstream-raw";
        cwd = if enabled then "source" else ".";
        run = if !enabled then ''
          mkdir -p "$out"
          printf disabled > "$out/status"
          printf 'doCheck=false; upstream UNRUN\n' > "$out/log"
        '' else ''

          mkdir -p "$out"
          set +e
          (
            set -e
            ${s.python}/bin/python3 tools/test.py --shell=${package}/bin/node --mode=release --timeout=120 \
              parallel/test-assert-deep parallel/test-buffer-tostring parallel/test-crypto-hash parallel/test-zlib-convenience-methods
          ) > "$out/log" 2>&1
          status=$?
          set -e
          printf '%s\n' "$status" > "$out/status"
          cat "$out/log" >&2
        '';
      })
    ];
  });
in
(package.testContext.mkTest {
  inherit package;
  name = "upstream";
  script = ''
    test "$(cat ${raw}/status)" = ${if enabled then "0" else "disabled"}
    cat ${raw}/log >&2
    printf '%s' ${if enabled then "upstream-pass" else "upstream-disabled"}
  '';
  expected = if enabled then "upstream-pass" else "upstream-disabled";
}).edit (spec: spec // {
  validation = {
    role = "upstream-acceptance";
    execution = raw;
    production = package.artifact;
    factory = "owned.mkTest";
  };
})
