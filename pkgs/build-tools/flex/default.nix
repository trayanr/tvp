{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  base = tvp.bases.default;
  defs = tvpLib.packages.mkDefs {
    "2.6.4" = {
      builder = ./build-2.6.4.nix;
      inherit base;
      deps = {
        bison = tvp.packages.bison_3_8_2;
        m4 = tvp.packages.m4_1_4_21;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.6.4";
      releases."2.6.4" = "sha256-6HquAyvwfCb4WsDtMlCZjDdiHZX4vXSLMfFbM8Re6ZU=";
    }
  ];
  pname = "flex";
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }: package: import ./tests { inherit pkgs tvpLib package; }
    ) { pkgs = tvpLib.tests.withBase { inherit pkgs base; }; };
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/westes/flex.git";
      normalise =
        tag:
        if pkgs.lib.hasPrefix "v" tag then
          pkgs.lib.removePrefix "v" tag
        else if pkgs.lib.hasPrefix "flex-" tag then
          pkgs.lib.removePrefix "flex-" tag
        else
          null;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
    };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
