{
  pkgs,
  tvpLib,
  package,
}:
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools;
  libraries = [ package ];
  tests = {
    version = {
      script = ''cc ${./fixtures/version.c} -lmpdec -o version; ./version'';
      expected = package.version;

    };
    c = {
      script = ''cc ${./fixtures/arithmetic.c} -lmpdec -o arithmetic; ./arithmetic'';
      expected = "0.3";

    };
    cxx = {
      script = ''c++ ${./fixtures/arithmetic.cc} -lmpdec++ -lmpdec -o arithmetic; ./arithmetic'';
      expected = "0.3";

    };
  };
}

// import ./native-contract.nix { inherit package; }

// (
  if
    (package ? specification)
    && (package.specification ? upstreamPlan)
    && (package.specification.upstreamCheck.enabled or true)
  then
    {
      # Independent native upstream registration.
      upstream = import ../native/upstream.nix { package = package; };
    }
  else
    { }
)
