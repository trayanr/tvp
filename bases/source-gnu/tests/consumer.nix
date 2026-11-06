# A complete small owned consumer: selected tools discover public interfaces,
# installed programs run without ambient providers, and evidence is separate.
{
  candidate,
  gmp,
  mpfr,
  mpc,
  jsonC,
}:
final:
let
  inherit (candidate) base tools lib;
  environment = final.base.environment final.environment;
in
{
  pname = "source-gnu-candidate-consumers";
  version = "1";
  src = null;
  inherit base;
  inherit (tools) bash coreutils;
  outputs = [
    "out"
    "evidence"
  ];
  environment = {
    tools = map (n: tools.${n}) [
      "python"
      "meson"
      "cmake"
      "ninja"
      "pkgConfig"
      "make"
      "sed"
      "grep"
      "findutils"
    ];
    libraries = [
      mpc
      jsonC
    ];
  };
  runtime.libraries = [
    gmp
    mpfr
    mpc
    jsonC
  ];
  plan = [
    (
      environment
      // {
        name = "consumer.qualify";
        run = ''
          ${tools.python}/bin/python3 -B ${./consumer.py} "$out" "$evidence" ${
            lib.escapeShellArg (
              builtins.toJSON {
                packages = builtins.mapAttrs (_: toString) {
                  inherit
                    gmp
                    mpfr
                    mpc
                    jsonC
                    ;
                };
                inherit (environment) env;
                compiler = toString candidate.toolchain.compiler;
                libc = toString candidate.toolchain.libc;
                driver = toString final.base.compiler;
                tools = builtins.mapAttrs (_: toString) tools;
                fixtures = "${./fixtures}";
              }
            )
          }
        '';
      }
    )
  ];
}
