{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "4.9" = {
      builder = ./build-4.9.nix;
      base = tvp.bases.default;
      deps = {
        acl = tvp.packages.acl_2;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.9";
      releases = {
        "4.9" = "sha256-biJrcy4c1zlGStaGK9Ghq6QteYKSLaelNRljHSSXUYE=";
        "4.10" = "sha256-uOchgrLslqNXTimYxHt6qmTMIM4ADY6awxPMB87PKMc=";
      };
    }
  ];
  pname = "gnused";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/sed/";
      # Capture whole filenames so signatures and archival README placeholders
      # cannot be mistaken for available tarballs by a partial regex match.
      pattern = "sed-[0-9][^\"<>[:space:]]*";
      normalise =
        file:
        let
          matched = builtins.match "sed-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|xz|bz2|lz)" file;
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
