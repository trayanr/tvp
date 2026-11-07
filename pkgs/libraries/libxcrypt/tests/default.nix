{
  pkgs,
  pkg-config,
  tvpLib,
  package,
  baseline,
  gnused,
  coreutils,
}:
if package ? testContext then
  import ./native-default.nix {
    inherit
      pkgs
      pkg-config
      tvpLib
      package
      baseline
      gnused
      coreutils
      ;
  }
else
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
  // (import ./validation.nix {
    inherit
      pkgs
      pkg-config
      package
      baseline
      ;
  })
  // (import ./upstream-fixtures.nix {
    inherit
      pkgs
      package
      gnused
      coreutils
      ;
  })
