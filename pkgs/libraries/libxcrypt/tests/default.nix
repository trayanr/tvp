{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    crypt = {
      script = ''
        cc ${./fixtures/crypt.c} -lcrypt -o crypt
        ./crypt
      '';
      extraInputs = [ package.tvp.cc ];
      expected = "ok";
    };
  };
}
