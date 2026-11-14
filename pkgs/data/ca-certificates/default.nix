{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  testLib = pkgs.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  formerRecipe = previous.publicArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  defs = tvpLib.packages.mkDefs {
    "2026-10-20" = {
      constructor = tvp.builder;
      builder = ./native/build-2026-10-20.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        inherit (tvp.packages) bash coreutils;
      };
    };
  };
  versionTable = formerRecipe.versionTable // {
    "2026-10-20" = formerRecipe.versionTable."2026-10-20" // {
      def = if native then defs."2026-10-20" else formerRecipe.versionTable."2026-10-20".def;
    };
  };
  publicArgs = formerRecipe // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://curl.se/ca/cacert-${version}.pem";
        inherit sha256;
      };
    testDeps = {
      diffutils = tvp.packages.diffutils;
      openssl = tvp.packages.openssl_4;
      grep = tvp.packages.gnugrep;
      findutils = tvp.packages.findutils;
    };
    extraArgs.mkTests = testLib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;
        openssl = package.tvp.declaredTestDependencies.openssl;
        pkgs =
          if package ? testContext then
            { lib = testLib; }
          else
            tvpLib.tests.withBase {
              inherit pkgs;
              base.stdenv = package.stdenv;
            };
      }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "ca-certificates";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = formerRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
