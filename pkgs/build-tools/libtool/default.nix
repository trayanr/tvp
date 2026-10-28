{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  base = tvp.bases.gcc13-owned;
  defs = tvpLib.packages.mkDefs {
    "2.6.2" = {
      builder = ./build-2.6.2.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        automake = tvp.packages.automake_1_19;
        m4 = tvp.packages.m4_1_4_21;
        file = base.components.floor.file;
      };
      patches = [
        {
          file = ./patches/declared-tools.patch;
          reason = "Store-layout adaptation: give libtoolize and generated libtool scripts declared Autoconf and Automake defaults while preserving upstream's environment overrides.";
        }
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.6.2";
      releases."2.6.2" = "sha256-LvEGfBbJfbkw/XQMybw9O6mlg4BK5axCzD6HGeSeGR4=";
    }
  ];
  pname = "libtool";
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
      url = "https://mirrors.kernel.org/gnu/libtool/";
      pattern = "libtool-[0-9][^\"]*\\.tar\\.gz";
      normalise =
        file:
        if pkgs.lib.hasPrefix "libtool-" file && pkgs.lib.hasSuffix ".tar.gz" file then
          pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "libtool-" file)
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
