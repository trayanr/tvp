# CLI assembly is separate from the package catalogue and its test policy.
{
  pkgs,
  tvp,
  tvpLib,
  canonical,
  bases,
  legacyBases,
  variantPackages,
  runtimeRegistry,
}:
let
  ownedCLI = import ./lib/owned-cli.nix {
    inherit (pkgs) lib;
    inherit (tvp.packages) bash coreutils;
    shellcheck = pkgs.shellcheck-minimal;
    platform = bases.default.platform;
  };
  tools = {
    dependencies = pkgs.callPackage ./dependencies {
      python3 = tvp.packages.python_3;
      inherit ownedCLI;
    };
    testRunner = pkgs.callPackage ./test-runner {
      python3 = tvp.packages.python_3;
      inherit ownedCLI;
    };
    provenance = pkgs.callPackage ./provenance.nix {
      inherit ownedCLI;
      coreutils = tvp.packages.coreutils;
      gawk = tvp.packages.gawk;
      gnused = tvp.packages.gnused;
      packages = canonical;
      inherit tvpLib variantPackages;
      registry = runtimeRegistry;
    };
    upstream = pkgs.callPackage ./upstream.nix {
      inherit ownedCLI;
      coreutils = tvp.packages.coreutils;
      curl = tvp.packages.curl;
      git = tvp.packages.git;
      gnugrep = tvp.packages.gnugrep;
      gnused = tvp.packages.gnused;
      packages = canonical;
      inherit tvpLib;
    };
    neutral = pkgs.callPackage ./neutral.nix {
      inherit ownedCLI;
      coreutils = tvp.packages.coreutils;
      gawk = tvp.packages.gawk;
      python3 = tvp.packages.python_3;
      packages = canonical;
      inherit tvpLib;
      graph = tvp.graph;
    };
    status =
      let
        # Status uses the cached source-owned CLI floor.
        tooling = (import ../bases/source-gnu { }).tools;
      in
      pkgs.callPackage ./status.nix {
        ownedCLI = import ./lib/owned-cli.nix {
          inherit (pkgs) lib;
          inherit (tooling) bash coreutils;
          shellcheck = pkgs.shellcheck-minimal;
          platform = bases.default.platform;
        };
        coreutils = tooling.coreutils;
        gnugrep = tooling.grep;
        gnused = tooling.sed;
        packages = canonical;
        inherit tvpLib;
        bases = legacyBases;
      };
  };
in
{
  inherit ownedCLI tools;
}
