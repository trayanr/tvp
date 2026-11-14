{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
package.testContext.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = package.specification.environment.tools;
  tests = {
    customization = {
      script = "echo customization";
      expected = import ./customization.nix { inherit package; };
    };
    steps-replacement = {
      script =
        let
          control = package.editSteps (_: [
            {
              name = "contract.probe";
              run = ''mkdir -p "$out"; printf '%s\n' 'edited plan executed' > "$out/marker"'';
            }
          ]);
        in
        ''cat ${control}/marker'';
      expected = "edited plan executed";
    };
    version = {
      script = ''test "$(awk '/^#define LINUX_VERSION_CODE / {print $3}' ${package}/include/linux/version.h)" = 395520; echo 6.9'';
      expected = "6.9";
    };
    compile = {
      script = ''
        cc -I${package}/include -DTVP_EXPECTED_VERSION_CODE=395520 ${./fixtures/api.c} -H -o api 2> headers.log
        trace=$(cat headers.log)
        case "$trace" in *${package}/include/linux/version.h*) ;; *) exit 1 ;; esac
        ./api
      '';
      expected = "ok";
    };
    payload = {
      script = ''
        test -z "$(find ${package}/include -type f ! -name '*.h' -print)"
        test -z "$(find ${package}/include -type l -print)"
        test ! -e ${package}/include/linux/sched/signal.h
        test ! -e ${package}/scripts
        test -f ${package}/share/licenses/linux-headers/COPYING
        echo UAPI
      '';
      expected = "UAPI";
    };
  };
}
