# Real override/edit invocation control for configured semantic helpers. The
# construction floor stays separate while the tested helper logs actual calls.
{
  tvp,
  package,
  helperName,
  invocation,
}:
let
  spec = package.specification;
  original = spec.helperCoreutils;
  helper = tvp.builder {
    recipe =
      { original }:
      final: {
        pname = "${package.pname}-helper-control";
        version = package.version;
        src = null;
        inherit (spec) base bash coreutils;
        plan = [
          (
            (spec.base.environment { tools = [ original ]; })
            // {
              name = "helper.wrapper";
              run = ''
                mkdir -p "$out/bin"
                cat > "$out/bin/${helperName}" <<'SCRIPT'
                #!${spec.bash}/bin/bash
                if test -n "''${TVP_HELPER_LOG:-}"; then echo ${helperName} >> "$TVP_HELPER_LOG"; fi
                exec ${original}/bin/${helperName} "$@"
                SCRIPT
                chmod +x "$out/bin/${helperName}"
              '';
            }
          )
        ];
      };
    args = {
      inherit original;
    };
    dependencyNames = [ "original" ];
    metadata.kind = "owned-test-support";
    selection.kind = "owned-test-support";
    mkTests = _: { };
  };
  overridden = package.override {
    coreutils = helper;
    doCheck = false;
  };
  edited = (package.override { doCheck = false; }).edit (s: s // { helperCoreutils = helper; });
in
assert overridden.drvPath == edited.drvPath;
package.testContext.mkSuite {
  inherit package;
  tools = spec.environment.tools ++ [ overridden ];
  tests.helper-override = {
    script = ''
      export TVP_HELPER_LOG="$PWD/helper.log"
      ${invocation overridden}
      test -s helper.log
      grep -Fx ${helperName} helper.log >&2
      echo configured-helper-executed
    '';
    expected = "configured-helper-executed";
  };
}
