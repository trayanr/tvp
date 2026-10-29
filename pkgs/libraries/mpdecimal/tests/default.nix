{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''cc ${./fixtures/version.c} -lmpdec -o version; ./version'';
      expected = package.version;
      extraInputs = [ package.tvp.cc ];
    };
    c = {
      script = ''cc ${./fixtures/arithmetic.c} -lmpdec -o arithmetic; ./arithmetic'';
      expected = "0.3";
      extraInputs = [ package.tvp.cc ];
    };
    cxx = {
      script = ''c++ ${./fixtures/arithmetic.cc} -lmpdec++ -lmpdec -o arithmetic; ./arithmetic'';
      expected = "0.3";
      extraInputs = [ package.tvp.cc ];
    };
  };
}
