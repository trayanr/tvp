{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.11" = {
      builder = ./build-3.11.nix;
      base = tvp.bases.default;
      deps = {
        pcre2 = tvp.packages.pcre2_10;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.11";
      releases = {
        "3.11" = "sha256-HbKu3eidDepCsW2VKPiUyNFdrk4ZC1muzHj1qVEnbqs=";
        "3.12" = "sha256-JkmyfA6Q5jLq3NdXvgbG6aT0jZQd5R58D4P/dkCKB7k=";
      };
    }
  ];
  pname = "gnugrep";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit pkgs tvpLib package;
        locale = tvp.packages.glibc_2;
      };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/grep/";
      # Capture the entire filename, including suffixes, before validating it.
      pattern = ''[^"<>/[:space:]]+\.tar\.[^"<>/[:space:]]+'';
      normalise =
        file:
        let
          archive = builtins.match "grep-([0-9]+(\\.[0-9]+)+)\\.tar\\.(gz|bz2|xz)" file;
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
