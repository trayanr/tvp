{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.10" = {
      builder = ./build-3.10.nix;
      base = tvp.bases.default;
      deps = {
        coreutils = tvp.packages.coreutils;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.10";
      releases = {
        "3.10" = "sha256-kOXpPMck5OvhLt6A3xY0Bjx6hVaSaFkZv+YLVWyb0J4=";
        "3.11" = "sha256-pz7wX+N91YX32HBo5KBjl2BBn4EBOL11xh3aofniEx4=";
        "3.12" = "sha256-fIt/n8hgkUH96pzs6FJJ0whiQ5H/Yd7a9Sj8szdyff0=";
      };
    }
  ];
  pname = "diffutils";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/diffutils/";
      # Capture whole filenames, including any README, signature or diff suffix.
      # Normalising a matched prefix would falsely count those as archives.
      pattern = ''[^"<>/[:space:]]+\.tar\.[^"<>/[:space:]]+'';
      normalise =
        file:
        let
          archive = builtins.match "diffutils-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|xz|bz2)" file;
        in
        if archive == null then null else builtins.head archive;
    };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
