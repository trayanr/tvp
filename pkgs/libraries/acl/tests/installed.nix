{
  package,
  lib,
  context,
}:
let
  commonTools =
    with package.specification.base.tools;
    [
      sed
      grep
      gawk
      diffutils
    ]
    ++ [ package.specification.base.compiler.bintools ];
in

context.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = commonTools;
  tests = {
    version = {
      script = ''
        ${package}/bin/getfacl --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        "$CC" ${./fixtures/acl.c} -lacl -o acl
        ./acl
      '';
      expected = "ok";
      tools = commonTools ++ [ package.tvp.cc ];
    };
  };
}
// (import ./installed-expanded.nix { inherit package lib context; })
// lib.optionalAttrs (!package.specification.installedInterface.propagateAttr) (
  import ./controls.nix { inherit package lib context; }
)
// (import ../../attr-crypt-split-tests.nix {
  inherit package lib context;
  compression = "gzip";
})
// lib.optionalAttrs (package.specification.upstreamCheck.enabled or true) {
  upstream = import ./upstream.nix { inherit package lib context; };
}
