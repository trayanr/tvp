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
              name = "acl.upstream-frontends";
              run = ''
                cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
                ${tools.python}/bin/python3 -B ${../../attr-acl-upstream-source.py} acl ${spec.base.shell}/bin/bash ${perl}/bin/perl ${../../compression-source-tree.py}
              '';
            }
          )
        ];
      upstreamCheck = spec.upstreamCheck // {
        tools = spec.upstreamCheck.tools ++ [
          spec.attr
          perl
          tools.python
        ];
        run = ''
          "$CC" ${../../../../lib/tests/filesystem-capabilities.c} -o .tvp-filesystem-probe
          # Keep the existing bounded interposer exception: the selected Grep
          # performs no user/group lookup; tested ACL programs remain preloaded.
          mkdir -p "$PWD/.tvp-check-tools"
          printf '%s\n' '#!${spec.base.shell}/bin/bash' 'unset LD_PRELOAD' \
            'exec ${tools.grep}/bin/grep "$@"' > .tvp-check-tools/grep
          chmod +x .tvp-check-tools/grep
          export PATH="$PWD/.tvp-check-tools:$PATH"
          status=0
          ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" check \
            ${
              if spec.upstreamProfile == "test" then "TEST_LOG_COMPILER" else "RUN_LOG_COMPILER"
            }="${tools.python}/bin/python3 -B ${
              if spec.upstreamProfile == "test" then
                ../../../../lib/tests/ordinary-test-runner.py
              else
                ../../../../lib/tests/filesystem-test-runner.py
            } ${
              if spec.upstreamProfile == "test" then "acl23" else "acl"
            } $PWD/.tvp-filesystem-probe $PWD/test/runwrapper" \
            || status=$?
          cat test-suite.log
          exit "$status"
        '';
      };
    }
  );
in
context.mkUpstream { package = checked; }
