{
  pkgs,
  pkg-config,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''
        ${package}/bin/getfacl --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        cc ${./fixtures/acl.c} -lacl -o acl
        ./acl
      '';
      expected = "ok";
      extraInputs = [ package.tvp.cc ];
    };
  };
}
// import ./expanded.nix {
  inherit
    pkgs
    pkg-config
    tvpLib
    package
    ;
}
