{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps.pager = tvp.packages.less;
        opts.upstreamPagerShim = true;
      };
      releases = {
        "1.13" = "sha256-dFTraTXbF8ZlVXbC4bD6vv04tNCTbg+H9IzQYs6RoFc=";
        "1.14" = "sha256-Aae4gb0iC/32Ffl7hxj4C9/T9q3ThbmT3Pbv0U6MCsY=";
      };
    }
    {
      def = {
        builder = ./build.nix;
        deps.pager = tvp.packages.less;
      };
      releases."1.15" = "sha256-mqDMeA3sFWuCgoRIM7NCq3ywjCXSzZoYac3Q3zHe/0g=";
    }
  ];
  packageMeta.upstream = {
    type = "directory-index";
    url = "https://mirrors.kernel.org/gnu/gzip/";
    pattern = "gzip-[0-9][^\"]*\\.(tar(\\.(gz|xz))?|zip|shar)";
    normalise =
      file:
      let
        matched = builtins.match "gzip-([0-9]+(\\.[0-9]+)*)\\.(tar(\\.(gz|xz))?|zip|shar)" file;
      in
      if matched == null then null else builtins.head matched;
    include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
  };
  pname = "gzip";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/gzip/gzip-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
    testDeps = {
      sentinel = tvp.lib.tests.fixtures.sentinel;
      alternateSource = tvp.lib.tests.fixtures.alternateSource;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.gzip = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
