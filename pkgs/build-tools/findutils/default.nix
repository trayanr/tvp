{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "4.10.0" = {
      builder = ./build-4.10.0.nix;
      base = tvp.bases.default;
      deps = {
        coreutils = tvp.packages.coreutils;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.10.0";
      releases."4.10.0" = "sha256-E4fgtn/yR9Kr3pmPkN+/cMFJE5Glnd/suK5ph4nwpPU=";
      releases."4.11.0" = "sha256-v9GcsGzHHzNS1WfpAoTYzawCrIl3S76t8LUzsMEUMv0=";
    }
  ];
  pname = "findutils";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/findutils/";
      pattern = "findutils-[0-9][^\"]*\\.tar\\.(gz|bz2|xz|lz)";
      # Multiple archive formats describe the same numeric release. The
      # directory-index adapter deduplicates the normalised versions.
      normalise =
        file:
        let
          matched = builtins.match "findutils-([0-9]+(\\.[0-9]+)+)\\.tar\\.(gz|bz2|xz|lz)" file;
        in
        if matched == null then null else builtins.head matched;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)+" version != null;
    };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
