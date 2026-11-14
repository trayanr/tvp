# Automake's test driver belongs to the restored test tree, not production.
{
  package,
  lib,
  context,
}:
let
  checked = package.edit (
    spec:
    spec
    // {
      upstreamPlan =
        artifact:
        spec.upstreamPlan artifact
        ++ [
          (
            (spec.base.environment { tools = [ spec.base.standardTools.python ]; })
            // {
              name = "libyaml.upstream-frontends";
              run = ''
                cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
                if [[ -e config/test-driver || -L config/test-driver ]]; then
                  ${spec.base.standardTools.python}/bin/python3 -B ${../../dbm-yaml-source.py} ${spec.base.shell}/bin/bash ${
                    lib.escapeShellArg (
                      builtins.toJSON {
                        selections = [ "config/test-driver" ];
                        requireConfigure = false;
                        libtoolAnchors = { };
                      }
                    )
                  }
                fi
              '';
            }
          )
        ];
    }
  );
in
context.mkUpstream { package = checked; }
