{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "0.20" = {
      builder = ./build-0.20.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6_3_0;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."0.20";
      releases = {
        "0.20" = "sha256-pVlqn7ils2XLYS5LlihzXW5n6RePrhNKgWrhlQF+d6o=";
        "0.26" = "sha256-oLXLBtJPn6nne1X6u+mjyUozYZA0XCVV+ZFbs46XZQQ=";
        "0.27" = "sha256-bYurtZ57Zy6Mt4cOh08/e4E7bgDmrz+LBPdXmWVkPVw=";
        "0.28" = "sha256-PcMbjhsYMp5C1d+/hN1V4VxZthVpoqskb2FJfZWS9yc=";
      };
    }
  ];
  pname = "isl";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://libisl.sourceforge.io/";
      # Capture the whole href; normalise rejects prefix/suffix junk and keeps
      # the exact version spelling (including 0.07).
      pattern = "href=\"[^\"]*\"";
      normalise =
        href:
        let
          link = builtins.match ''href="([^"]*)"'' href;
          match =
            if link == null || pkgs.lib.hasSuffix "/" (builtins.head link) then
              null
            else
              builtins.match ''isl-([0-9]+(\.[0-9]+)*)\.tar\.(gz|bz2|xz)'' (
                builtins.baseNameOf (builtins.head link)
              );
        in
        if match == null then null else builtins.head match;
    };
    extraArgs.mkTests = isl: import ./tests { inherit pkgs tvpLib isl; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
