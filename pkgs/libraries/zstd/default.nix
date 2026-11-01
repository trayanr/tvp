{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.5.6" = {
      builder = ./build-1.5.6.nix;
      base = tvp.bases.default;
      deps = {
        zlib = tvp.packages.zlib_1;
        xz = tvp.packages.xz_5;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.5.6";
      releases = {
        "1.5.6" = "sha256-jCngbPQqrMHq/EB3ri7Gxvy5amJhV+BZPV6Co0/UA8E=";
        "1.5.7" = "sha256-6zPlH0mhXgI5UM14Jcp0pKK0Pbg1SCWsJPwbfuCeb6M=";
      };
    }
  ];
  pname = "zstd";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    testDeps = {
      gzip = tvp.packages.gzip;
    };

    extraArgs.mkTests =
      zstd:
      import ./tests {
        inherit pkgs tvpLib zstd;
        inherit (zstd.tvp.declaredTestDependencies) gzip;
      };
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/facebook/zstd";
      normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else null;
      include = version: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" version != null;
    };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
