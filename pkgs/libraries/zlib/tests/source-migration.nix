# Independent upstream execution through the existing owned test factory.
# Re-enter only effective source preparation/configure/build steps; never the
# installed artifact, finalization, or another version's procedure.
{
  tvp,
  pkgs,
  package,
}:
let
  s = package.specification;
  prefix = pkgs.lib.take (pkgs.lib.lists.findFirstIndex (
    step: step.name == "zlib.install"
  ) (throw "missing Zlib install boundary") package.buildSteps) package.buildSteps;
  upstream =
    (package.testContext.mkTest {
      inherit package;
      name = "upstream";
      tools = [
        s.tools.gnumake
        s.tools.grep
      ];
      script = ''
        export LD_LIBRARY_PATH="$PWD:''${LD_LIBRARY_PATH-}"
        status=0
        # Older examples share foo.gz. Upstream test groups must stay serial.
        ${s.tools.gnumake}/bin/make -j1 SHELL=${s.bash}/bin/bash test > upstream-check.log 2>&1 || status=$?
        cat upstream-check.log >&2
        if test "$status" -ne 0; then exit "$status"; fi
        if ${s.tools.grep}/bin/grep -E 'FAILED|FAIL|XPASS' upstream-check.log >&2; then exit 1; fi
        printf upstream-passed
      '';
      expected = "upstream-passed";
    }).editSteps
      (plan: prefix ++ map (step: step // { cwd = "source"; }) plan);
in
pkgs.lib.optionalAttrs s.doCheck { inherit upstream; }
