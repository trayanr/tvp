{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''
        ${package}/bin/getfattr --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        cc ${./fixtures/policy.c} -lattr -o policy
        ./policy
      '';
      expected = "ok";
      extraInputs = [ package.tvp.cc ];
    };
  };
}
