{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.13" = {
      builder = ./build-1.13.nix;
      base = tvp.bases.default;
      deps = {
        gnugrep = tvp.packages.gnugrep;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.13";
      releases = {
        "1.13" = "sha256-dFTraTXbF8ZlVXbC4bD6vv04tNCTbg+H9IzQYs6RoFc=";
        "1.14" = "sha256-Aae4gb0iC/32Ffl7hxj4C9/T9q3ThbmT3Pbv0U6MCsY=";
        "1.15" = "sha256-mqDMeA3sFWuCgoRIM7NCq3ywjCXSzZoYac3Q3zHe/0g=";
      };
    }
  ];
  pname = "gzip";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit pkgs tvpLib package;
        coreutils = tvp.packages.coreutils;
      };
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
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
