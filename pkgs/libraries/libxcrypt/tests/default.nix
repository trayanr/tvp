{
  pkgs,
  tvpLib,
  package,
  baseline,
}:
(tvpLib.tests.mkSuite {
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
})
// (import ./validation.nix { inherit pkgs package baseline; })
// (import ./upstream-fixtures.nix { inherit pkgs package; })
