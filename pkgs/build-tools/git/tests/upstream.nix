# Independent private upstream preparation/construction and raw execution.
# Production A/F never references this factory. Raw nonzero statuses stay raw.
{ package }:
let
  s = package.specification;
  steps = import ../../../../lib/build-steps.nix;
  prepared = builtins.filter (x: !(builtins.elem x.name ["git.build" "git.install"]))
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
    plan = (if enabled then prepared ++ [ s.upstreamPreparation ] else [ ]) ++ [
      (environment // {
        name = "git.upstream-raw";
        cwd = if enabled then "source" else ".";
        run = if !enabled then ''
          mkdir -p "$out"
          printf disabled > "$out/status"
          printf 'doCheck=false; upstream UNRUN\n' > "$out/log"
        '' else ''
          ${s.gnumake}/bin/make -j"$NIX_BUILD_CORES" prefix=${s.configurePrefix} RUNTIME_PREFIX=YesPlease \
            SHELL=${s.bash}/bin/bash SHELL_PATH=${s.bash}/bin/bash TEST_SHELL_PATH=${s.bash}/bin/bash \
            PERL_PATH=${s.perl}/bin/perl PYTHON_PATH=${s.python}/bin/python3 \
            CURL_CONFIG=${s.curl}/bin/curl-config NO_GETTEXT=YesPlease NO_TCLTK=YesPlease USE_LIBPCRE2=YesPlease \
            t/helper/test-tool t/helper/test-fake-ssh GIT-BUILD-OPTIONS
          ${s.gnumake}/bin/make -C templates SHELL_PATH=${s.bash}/bin/bash PERL_PATH=${s.perl}/bin/perl
          # This is generated private harness configuration, not a raw receipt.
          # Retain Perl prerequisites against the installed module tree instead
          # of silently disabling them because private perl/build/lib is absent.
          ${s.helperPython}/bin/python3 -B - <<'PYTHON'
          from pathlib import Path
          import re
          p = Path('GIT-BUILD-OPTIONS')
          data = p.read_text()
          pattern = r"(?m)^GIT_TEST_GITPERLLIB='[^'\n]+/perl/build/lib'$"
          result, count = re.subn(pattern, "GIT_TEST_GITPERLLIB='${package}/share/perl5'", data)
          assert count == 1
          p.write_text(result)
          PYTHON
          export GIT_TEST_INSTALLED=${package}/bin
          cd t
          mkdir -p "$out"
          set +e
          (
            set -e
            # t0001 setgid remains sandbox-excluded, unwaived.
            ${s.bash}/bin/bash t0000-basic.sh --verbose-log &&
            ${s.bash}/bin/bash t0008-ignores.sh --verbose-log &&
            ${s.bash}/bin/bash t1300-config.sh --verbose-log
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
