{
  pkgs,
  pkg-config,
  tvpLib,
  package,
  baseline,
  gnused,
  coreutils,
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

(package.testContext.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = commonTools;
  tests = {
    crypt = {
      script = ''
        "$CC" ${./fixtures/crypt.c} -lcrypt -o crypt
        ./crypt
      '';
      tools = commonTools ++ [ package.tvp.cc ];
      expected = "ok";
    };
  };
})
// (import ./native-validation.nix {
  inherit
    pkgs
    pkg-config
    package
    baseline
    ;
})
// (import ./native-upstream-fixtures.nix {
  inherit
    pkgs
    package
    gnused
    coreutils
    ;
})

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
