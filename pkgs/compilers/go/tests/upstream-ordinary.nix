# Independent raw upstream execution R and strict acceptance U. Neither is an
# input of the ordinary compiler's artifact or public finalization.
{
  package,
  tvp,
  lib,
}:
let
  s = package.specification;
  execution = tvp.builder {
    recipe = { }: _: {
      pname = "go-upstream-execution";
      inherit (s)
        version
        base
        bash
        coreutils
        ;
      src = null;
      validationRole = "upstream-execution";
      plan = [
        (
          ((s.base.override { compiler = s.runtime.compiler; }).environment {
            tools = s.environment.tools ++ [
              s.binutils
              s.runtime.compiler
            ];
          })
          // {
            name = "go.capture-upstream";
            run = ''
              mkdir -p tree "$out"
              cp -a ${package}/share/go/. tree/
              chmod -R u+w tree
              export GOROOT="$PWD/tree"
              export CC=${lib.escapeShellArg s.runtime.cc} CXX=${lib.escapeShellArg s.runtime.cxx}
              export GO_LDSO=${lib.escapeShellArg s.runtime.loader} CGO_ENABLED=1
              export GOENV=off GOTOOLCHAIN=local GOPROXY=off GOSUMDB=off
              export GOCACHE="$TMPDIR/go-cache" GOPATH="$TMPDIR/go-work"
              cd tree/src
              status=0
              ../bin/go tool dist test ${lib.escapeShellArgs s.upstreamArguments} > "$out/upstream.log" 2>&1 || status=$?
              printf '%s\n' "$status" > "$out/upstream.exit"
            '';
          }
        )
      ];
    };
    args = { };
    dependencyNames = [ ];
    metadata.kind = "owned-validation";
    selection.kind = "owned-validation";
    mkTests = _: { };
  };
  acceptance = package.testContext.mkTest {
    package = execution;
    name = "upstream-audit";
    tools = [ s.grep ];
    script = ''
      test "$(cat ${execution}/upstream.exit)" = 0
      grep -E '^ALL TESTS PASSED' ${execution}/upstream.log >/dev/null
      printf passed
    '';
    expected = "passed";
  };
in
{
  inherit execution acceptance;
}
