{
  package,
  lib,
  context,
  helperName,
  invocation,
}:

let
  spec = package.specification;
  original = spec.helperCoreutils;
  helper =
    (context.mkTest {
      inherit package;
      name = "helper-control";
      script = ":";
      expected = "";
    }).edit
      (
        old:
        old
        // {
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
        }
      );
  argumentOverride = package.override {
    coreutils = helper;
    doCheck = false;
  };
  selectHelper = s: s // { helperCoreutils = helper; };
  # Retained specification edits run after recipe arguments. Select the probe
  # helper after those edits when testing an already edited package.
  overridden =
    if (package.tvp.customization.edits or 0) > 0 then
      argumentOverride.edit selectHelper
    else
      argumentOverride;
  edited = (package.override { doCheck = false; }).edit selectHelper;
in
assert overridden.drvPath == edited.drvPath;
context.mkSuite {
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
