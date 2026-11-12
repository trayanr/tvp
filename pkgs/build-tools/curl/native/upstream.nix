# Independent source validation through the existing owned test factory.
# Reconstruct a private tree; no validation producer is an input to A or F.
{ package }:
let
  s = package.specification;
  check = s.upstreamCheck;
  raw = (package.testContext.mkTest {
    inherit package;
    name = "upstream-raw";
    script = ":";
    expected = "";
  }).edit (test: test // {
    validationRole = "upstream-execution";
    plan = [ {
      name = "upstream.initialize";
      run = ''mkdir -p "$out"'';
    } ] ++ s.upstreamPlan ++ [ (check // {
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
        for evidence in upstream-tests.status upstream-tests.log; do
          if test -f "$evidence"; then cp "$evidence" "$out/raw/"; fi
        done
      '';
    }) ];
  });
in
(package.testContext.mkTest {
  package = raw;
  name = "upstream";
  script = ''
    cat ${raw}/raw/log >&2
    test "$(cat ${raw}/raw/status)" = 0
    test "$(cat ${raw}/raw/upstream-tests.status)" = 0
    grep -F "TESTDONE: 10 tests out of 10 reported OK" ${raw}/raw/upstream-tests.log >&2
    printf upstream-ok
  '';
  expected = "upstream-ok";
}).edit (test: test // {
  validation = {
    role = "upstream-acceptance";
    execution = raw;
    factory = "owned.mkTest";
  };
  passthru = test.passthru // { upstreamExecution = raw; };
})
