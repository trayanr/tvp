{
  package,
  lib,
  context,
}:

let
  mkSuite =
    args:
    context.mkSuite {
      inherit package;
      libraries = [ package ];
      tests = builtins.mapAttrs (
        _: test:
        (builtins.removeAttrs test [ "extraInputs" ])
        // {
          tools =
            (test.tools or [ ])
            ++ (test.extraInputs or [ ])
            ++ [
              package.specification.gawk or package.specification.base.tools.gawk
              package.specification.grep or package.specification.base.tools.grep
              package.specification.sed or package.specification.base.tools.sed
            ];
        }
      ) args.tests;
    };
in
mkSuite {
  inherit package;
  tests = {
    version = {
      script = "patchelf --version | awk '{print $2}' ";
      expected = package.version;
    };
    elf = {
      script = ''
        cc ${./fixtures/hello.c} -o hello
        interpreter=$(patchelf --print-interpreter hello)
        patchelf --set-rpath "$PWD/unused:${package.tvp.cc.libc}/lib" hello
        test "$(patchelf --print-rpath hello)" = "$PWD/unused:${package.tvp.cc.libc}/lib"
        patchelf --set-interpreter "$interpreter" hello
        ./hello
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
  };
}

// import ./current-owned.nix { inherit package lib context; }
