{
  pkgs,
  tvpLib,
  mpc,
}:
if mpc ? testContext then
  mpc.testContext.mkSuite {
    package = mpc;
    libraries = [ mpc ];
    tests = {
      version = {
        script = ''"$CC" ${./fixtures/version.c} -lmpc -lmpfr -lgmp -o version; ./version'';
        expected = mpc.version;
      };
      arithmetic = {
        script = ''"$CC" ${./fixtures/arithmetic.c} -lmpc -lmpfr -lgmp -o arithmetic; ./arithmetic'';
        expected = "25";
      };
    };
  }
else
  tvpLib.tests.mkSuite {
    inherit pkgs;
    package = mpc;
    tests = {
      version = {
        script = ''cc ${./fixtures/version.c} -lmpc -lmpfr -lgmp -o version; ./version'';
        expected = mpc.version;
        extraInputs = [ mpc.tvp.cc ];
      };
      arithmetic = {
        script = ''cc ${./fixtures/arithmetic.c} -lmpc -lmpfr -lgmp -o arithmetic; ./arithmetic'';
        expected = "25";
        extraInputs = [ mpc.tvp.cc ];
      };

    };
  }
