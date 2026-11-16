{
  package,
  lib,
  context,
}:
let
  s = package.specification;
  tools = s.base.tools;
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
                spec.perl
              ];
            })
            // {
              name = "libxcrypt.upstream-frontends";
              run = ''
                cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
                ${tools.python}/bin/python3 -B ${../../attr-crypt-upstream-source.py} libxcrypt ${spec.base.shell}/bin/bash ${spec.perl}/bin/perl ${../../compression-source-tree.py}
              '';
            }
          )
        ];
    }
  );
in
context.mkUpstream { package = checked; }
