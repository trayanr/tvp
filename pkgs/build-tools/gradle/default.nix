{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."gradle";
  retained = prior.constructionRecipe or prior;
  earlier = import ../../../bases/source-gnu { };
  full = tvp.baseTiers.full;
  profileBase = full.override {
    shell = tvp.packages.bash;
    coreutils = tvp.packages.coreutils;
    standardTools = {
      python = earlier.tools.python;
    };
  };
  pname = "gradle";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-9.3.1-current.nix;
        base = profileBase;
        deps = {
          jdk = tvp.packages.jdk_21;
          python = tvp.packages.python_3;
          unzip = tvp.packages.unzip;
        };
        blob = {
          reason = "Pinned upstream Gradle distribution with its bundled Java bytecode and native service libraries.";
          needs = "Source Gradle bootstrap and a locked source dependency repository.";
          blocked.package = "gradle-from-source";
        };
      };
      releases = {
        "9.3.1" = "sha256-F/J3hn9pFNYbGqAu+rG6e7Q5rWUspIXNjKaEL8zsbkM=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // {
    grep = tvp.packages.gnugrep;
    sed = tvp.packages.gnused;
    findutils = tvp.packages.findutils;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://services.gradle.org/distributions/gradle-${version}-all.zip";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."gradle" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
