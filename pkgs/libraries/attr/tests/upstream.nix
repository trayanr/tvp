{
  package,
  lib,
  context,
}:
let
  s = package.specification;
  tools = s.base.tools;
  perl = package.tvp.declaredTestDependencies.perl;
  checked = package.edit (
    spec:
    spec
    // {
      upstreamPlan =
        artifact:
        spec.upstreamPlan artifact
        ++ [
          (
            (spec.base.environment {
              tools = [
                tools.python
                perl
              ];
            })
            // {
              name = "attr.upstream-frontends";
              run = ''
                cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
                ${tools.python}/bin/python3 -B ${../../attr-acl-upstream-source.py} attr ${spec.base.shell}/bin/bash ${perl}/bin/perl ${../../compression-source-tree.py}
              '';
            }
          )
        ];
      upstreamCheck = spec.upstreamCheck // {
        tools = spec.upstreamCheck.tools ++ [
          perl
          tools.python
        ];
        run = ''
          "$CC" ${../../../../lib/tests/filesystem-capabilities.c} -o .tvp-filesystem-probe
          status=0
          ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" check \
            ${
              if spec.upstreamProfile == "test" then "TEST_LOG_COMPILER" else "RUN_LOG_COMPILER"
            }="${tools.python}/bin/python3 -B ${
              if spec.upstreamProfile == "test" then
                ./legacy-test-runner.py
              else
                ../../../../lib/tests/filesystem-test-runner.py
            } ${
              if spec.upstreamProfile == "test" then "" else "attr "
            }$PWD/.tvp-filesystem-probe $PWD/test/run" \
            || status=$?
          cat test-suite.log
          exit "$status"
        '';
      };
    }
  );
in
context.mkUpstream { package = checked; }
