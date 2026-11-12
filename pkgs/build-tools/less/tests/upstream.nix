# Independent private upstream preparation/construction and raw execution.
# Production A/F never references this factory. Raw nonzero statuses stay raw.
{ package }:
let
  s = package.specification;
  steps = import ../../../../lib/build-steps.nix;
  prepared = builtins.filter (x: !(builtins.elem x.name ["less.build" "less.install"]))
    (steps.partition package.buildSteps).first;
  environment = s.base.environment (s.environment // { tools = s.environment.tools ++ [ package.tvp.declaredTestDependencies.perl package.tvp.declaredTestDependencies.diffutils ]; });
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
        name = "less.upstream-raw";
        cwd = if enabled then "source" else ".";
        run = if !enabled then ''
          mkdir -p "$out"
          printf disabled > "$out/status"
          printf 'doCheck=false; upstream UNRUN\n' > "$out/log"
        '' else ''
          ${s.gnumake}/bin/make SHELL=${s.bash}/bin/bash LESSTEST=1 LDFLAGS="''${LDFLAGS-} -Wl,--wrap=popen,--wrap=pclose,--wrap=system"
          ${s.gnumake}/bin/make -C lesstest SHELL=${s.bash}/bin/bash CC="$CC" CFLAGS="''${CFLAGS-} -I${s.ncurses}/include/ncursesw"
          mkdir -p "$out"
          set +e
          (
            set -e
            (cd lesstest; ${package.tvp.declaredTestDependencies.perl}/bin/perl ./runtest -e -l ../less_t lt)
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
