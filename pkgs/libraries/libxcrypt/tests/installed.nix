{
  package,
  lib,
  context,
}:
let
  commonTools =
    with package.specification.base.standardTools;
    [
      sed
      grep
      gawk
      diffutils
    ]
    ++ [ package.specification.base.compiler.bintools ];
in

(context.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = commonTools;
  tests = {
    crypt = {
      script = ''
        "$CC" ${./fixtures/crypt.c} -lcrypt -o crypt
        ./crypt
      '';
      tools = commonTools ++ [ package.tvp.cc ];
      expected = "ok";
    };
  };
})
// (import ./installed-abi.nix { inherit package lib context; })
// (import ./tracker-fixtures.nix { inherit package lib context; })
// (import ./controls.nix { inherit package lib context; })
// (import ../../attr-crypt-split-tests.nix { inherit package lib context; })
// lib.optionalAttrs (package.specification.upstreamCheck.enabled or true) {
  upstream = import ./checkpoint-upstream.nix { inherit package lib context; };
}
