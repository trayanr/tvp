# Independent source validation through the existing owned test factory.
# Reconstruct a private tree; no validation producer is an input to A or F.
{ package }:
let
  s = package.specification;
  check = s.upstreamCheck;
  # Backport the later upstream locale fixture fix only to the affected test
  # tree. Production and the other releases keep their existing identities.
  upstreamPlan =
    if s.version != "5.30.3" then
      s.upstreamPlan
    else
      assert
        builtins.length (builtins.filter (step: step.name == "perl.prepare") s.upstreamPlan) == 1
        || throw "Perl 5.30 locale test preparation requires one perl.prepare step";
      map (
        step:
        if step.name == "perl.prepare" then
          step
          // {
            run =
              step.run
              + ''
                ${s.python}/bin/python3 -B ${./close-locale-data.py} "$PWD"
              '';
          }
        else
          step
      ) s.upstreamPlan;
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
            ++ upstreamPlan
            ++ [
              (
                check
                // {
                  name = "upstream.capture";
                  enabled = true;
                  run = ''
                    mkdir -p "$out/raw"
                    cat > "$TVP_SOURCE_ROOT/upstream-check.sh" <<'TVP_UPSTREAM_CHECK'
                    ${check.run}
                    TVP_UPSTREAM_CHECK
                    status=0
                    ${s.bash}/bin/bash -euo pipefail "$TVP_SOURCE_ROOT/upstream-check.sh" > "$out/raw/log" 2>&1 || status=$?
                    printf '%s\n' "$status" > "$out/raw/status"

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
        factory = "owned.mkTest";
      };
      passthru = test.passthru // {
        upstreamExecution = raw;
      };
    }
  )
