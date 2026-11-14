{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."gn";
  retained = prior.constructionRecipe or prior;
  earlier = import ../../../bases/source-gnu { };
  full = tvp.baseTiers.full;
  profileBase = full.override {
    shell = tvp.packages.bash;
    coreutils = tvp.packages.coreutils;
    standardTools = {
      python = earlier.tools.python;
      ninja = tvp.packages.ninja;
      patchelf = tvp.packages.patchelf;
    };
  };
  pname = "gn";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-20260707-current.nix;
        base = profileBase;
        deps = {
          binutils = tvp.packages.binutils;
        };
        opts = {
          revision = "b8becbd4f7979f63ab3542524b2b4d8db2ce3b52";
          hardeningDisable = [ "format" ];
          allowWarnings = true;
        };
      };
      releases = {
        "20260707" = "sha256-LFUIa4E93KbZWqrNTXK1AbNtbI1cOygwkfAsiB4L8dY=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // { };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import ./native/source.nix {
        inherit (earlier.tools) bash coreutils python;
        curl = tvp.packages.curl;
        caCertificates = tvp.packages.ca-certificates;
        inherit sha256;
        revision = "b8becbd4f7979f63ab3542524b2b4d8db2ce3b52";
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."gn" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
