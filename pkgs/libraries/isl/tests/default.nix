{
  pkgs,
  tvpLib,
  isl,
}:
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = isl;
  tests = {
    version = {
      script = ''
        cc ${./fixtures/version.c} -lisl -lgmp -o version
        ./version | grep -oE '[0-9]+\.[0-9]+'
      '';
      expected = isl.version;
      extraInputs = [ isl.tvp.cc ];
    };
    arithmetic = {
      script = ''cc ${./fixtures/arithmetic.c} -lisl -lgmp -o arithmetic; ./arithmetic'';
      expected = "5";
      extraInputs = [ isl.tvp.cc ];
    };

  };
}
