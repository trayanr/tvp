{ pkgs, tvp }:
let
  retained = import ./retained-construction.nix { inherit pkgs tvp; };
  pname = "glibc";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-2.39.nix;
        base = tvp.baseTiers.full;
        deps = {
          # Raw target GCC; distinct from BUILD_CC from the closed host base.
          gcc = tvp.packages.gcc;
          binutils = tvp.packages.binutils_2;
          linuxHeaders = tvp.packages.linux-headers;
          bison = tvp.packages.bison;
          python3Minimal = tvp.packages.python-minimal_3;
        };
        patches = [
          {
            file = ./patches/store-cache.patch;
            reason = "Retain per-store ld.so.cache and ld.so.conf, including loader diagnostics, instead of host /etc.";
          }
          {
            file = ./patches/fnmatch-gcc16.patch;
            reason = "GCC16 -O2 diagnoses four already documented fnmatch false positives outside the old -Os suppression. Extend those local diagnostic regions, as qualified in the source-GNU bootstrap reference.";
          }
        ];
      };
      releases."2.39" = "sha256-93vUfPgXDFc2Wue/hmlsEYrbOxINMlnGTFAtPcHi2SY=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta = retained.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/glibc/glibc-${version}.tar.xz";
        inherit sha256;
      };
    tests = (import ./tests/installed.nix);
  };
  # Preserve only the historical named test-factory override, lazily.
  recipe = family // {
    extraArgs = family.extraArgs // {
      mkTests = import ./tests/caller-factory.nix { inherit pkgs tvp; };
    };
  };
  canonical = tvp.lib.packages.mkVersions recipe;
in
{
  recipes.glibc = recipe // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
