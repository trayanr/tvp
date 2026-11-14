# Execute upstream checks against a private copy of the compiled A checkpoint.
{ package }:
let
  s = package.specification;
  check = s.upstreamCheck;
  raw =
    (package.testContext.mkTest {
      inherit package;
      name = "upstream-raw";
      script = ":";
      expected = "";
    }).edit
      (
        test:
        test
        // {
          validationRole = "upstream-execution";
          plan =
            [
              {
                name = "upstream.initialize";
                run = ''mkdir -p "$out"'';
              }
            ]
            ++ s.upstreamPlan package.artifact
            ++ [
              (
                check
                // {
                  name = "upstream.capture";
                  enabled = true;
                  cwd = ".";
                  tools = check.tools ++ [ s.base.standardTools.findutils ];
                  run = ''
                    mkdir -p "$out/raw"
                    cat > "$TVP_SOURCE_ROOT/upstream-check.sh" <<'TVP_UPSTREAM_CHECK'
                    ${check.run}
                    TVP_UPSTREAM_CHECK
                    status=0
                    cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
                    ${s.bash}/bin/bash -euo pipefail "$TVP_SOURCE_ROOT/upstream-check.sh" > "$out/raw/log" 2>&1 || status=$?
                    printf '%s\n' "$status" > "$out/raw/status"
                    mkdir -p "$out/raw/records"
                    ${s.base.standardTools.findutils}/bin/find . -type f \( -name '*.trs' -o -name '*.log' \) \
                      -exec ${s.coreutils}/bin/cp --parents --target-directory="$out/raw/records" -- {} +
                  '';
                }
              )
            ];
        }
      );
in
(package.testContext.mkTest {
  package = raw;
  name = "upstream";
  script = ''
    cat ${raw}/raw/log >&2
    test "$(cat ${raw}/raw/status)" = 0
    printf upstream-ok
  '';
  expected = "upstream-ok";
}).edit
  (
    test:
    test
    // {
      validation = {
        role = "upstream-acceptance";
        execution = raw;
        production = package.artifact;
        factory = "owned.mkTest";
      };
      passthru = test.passthru // {
        upstreamExecution = raw;
      };
    }
  )
