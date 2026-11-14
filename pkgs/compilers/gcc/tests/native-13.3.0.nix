# Reuse every shared GCC 13 test and fixture with the owned test factory.
{
  package,
  tvp,
  lib,
}:
let
  s = package.specification;
  gcc = package // {
    platform.dynamicLinker = "lib/ld-linux-x86-64.so.2";
    tvp = package.tvp // {
      deps = package.tvp.deps // {
        glibc = s.glibc;
        binutils = s.binutils;
      };
    };
  };
  pkgs = {
    inherit lib;
    writeText = builtins.toFile;
    runCommand =
      name: attrs: script:
      (package.testContext.mkTest {
        inherit package name;
        script = ":";
        expected = "";
      }).edit
        (
          test:
          test
          // {
            plan = [
              (
                (s.base.environment s.environment)
                // {
                  name = "gcc.${name}";
                  run = script;
                }
              )
            ];
          }
        );
  };
in
(import ./default.nix {
  inherit pkgs gcc;
  tvpLib.tests.mkSuite =
    args:
    package.testContext.mkSuite {
      inherit package;
      tools = s.environment.tools;
      tests = args.tests // {
        tool-overrides = args.tests.tool-overrides // {
          script =
            builtins.replaceStrings
              [ "chmod +x tools/as tools/ld" ]
              [
                "${s.sed}/bin/sed -i '1c#!${s.bash}/bin/bash' tools/as tools/ld\nchmod +x tools/as tools/ld"
              ]
              args.tests.tool-overrides.script;
        };
      };
    };
})
// {
  upstream-audit = (import ./upstream-13.3.0.nix { inherit package tvp lib; }).acceptance;
}
