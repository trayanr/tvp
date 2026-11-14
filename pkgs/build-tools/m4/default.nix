{ pkgs, tvp }:
let
  packageRecipes = tvp.lib.packages.mkDefs {
    "1.4.19" = {
      builder = ./build.nix;
      deps = { };
      # Bundled gnulib's C23 attribute placement is fixed in 1.4.20.
      opts.cStandard = "gnu17";
    };
    "1.4.20" = {
      builder = ./build.nix;
      deps = { };
    };
  };
  versionTable = tvp.lib.packages.mkTable [
    {
      def = packageRecipes."1.4.19";
      releases."1.4.19" = "sha256-O+SibYJf/f2lKlb8QyRkVpiaNjAJPM7T+930dx7linA=";
    }
    {
      def = packageRecipes."1.4.20";
      releases = {
        "1.4.20" = "sha256-asT8Mc5EDevmOYfC67+de2Y05np8Mnklfcc2Hei9s+8=";
        "1.4.21" = "sha256-OK5Z96ML+cEIGTzFwl+7BgFPIeIwx+3i7/YU97fDftg=";
      };
    }
  ];
  pname = "m4";
  retained = import ./retained { inherit pkgs tvp; };
  excludedVersions = pkgs.lib.filterAttrs (
    _: entry: (entry.status.level or "ok") == "broken"
  ) retained.versionTable;
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    inherit (retained) packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/m4/m4-${version}.tar.gz";
        inherit sha256;
      };
    # These are test-only choices. They never participate in production defaults.
    testDeps = {
      runtimeShell = tvp.packages.bash_5;
      alternateCoreutils = tvp.packages.coreutils;
      pkgConfig = tvp.packages.pkg-config;
      mpfr = tvp.packages.mpfr;
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
    };
    tests = import ./tests;
  };
  canonical =
    tvp.lib.packages.mkVersions family
    // tvp.lib.packages.mkVersions (retained // { versionTable = excludedVersions; });
in
{
  recipes.m4 = family // {
    constructionRecipe = retained;
    inherit excludedVersions;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases {
    inherit pname canonical;
    versionTable = versionTable // excludedVersions;
  };
}
