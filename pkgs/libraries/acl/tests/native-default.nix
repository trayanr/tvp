{
  pkgs,
  pkg-config,
  tvpLib,
  package,
}:
let
  commonTools = with package.tvp.declaredDependencies; [
    sed
    grep
    gawk
    diffutils
    binutils
  ];
in

package.testContext.mkSuite {
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
// import ./native-expanded.nix {
  inherit
    pkgs
    pkg-config
    tvpLib
    package
    ;
}
