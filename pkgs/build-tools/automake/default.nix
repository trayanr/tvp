{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  base = tvp.bases.default;
  defs = tvpLib.packages.mkDefs {
    "1.19" = {
      builder = ./build-1.19.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        perl = tvp.packages.perl_5_44_0;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.19";
      releases."1.19" = "sha256-4+LC46vzeJgTjbW2wdHcNckWDFl4vnlH0sdBcFJR1EU=";
    }
  ];
  pname = "automake";
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }: package: import ./tests { inherit pkgs tvpLib package; }
    ) { pkgs = tvpLib.tests.withBase { inherit pkgs base; }; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/automake/";
      pattern = "automake-[0-9][^\"]*\\.tar\\.gz";
      normalise =
        file:
        if pkgs.lib.hasPrefix "automake-" file && pkgs.lib.hasSuffix ".tar.gz" file then
          pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "automake-" file)
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
