{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "4.3" = {
      builder = ./build-4.3.nix;
      base = tvp.bases.default;
      deps = { };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.3";
      releases."4.3" = "sha256-4F/d5HxffKRctpfpc4lP9PXXnhO3UO1X17Ztje/Hjhk=";
      releases."4.4" = "sha256-WB9NToctp0s5Qch0IViYp9NYAvA3Mr3M7h1KeXkQXRg=";
      releases."4.4.1" = "sha256-3Rb7HWe/q3mnL16DkHNcSePo5wtJRaFasfgd23hlj7M=";
    }
  ];
  pname = "gnumake";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      };
    packageMeta = {
      upstream = {
        type = "directory-index";
        url = "https://mirrors.kernel.org/gnu/make/";
        pattern = "make-[0-9][^\"]*\\.tar\\.gz";

        normalise =
          file:
          if pkgs.lib.hasPrefix "make-" file && pkgs.lib.hasSuffix ".tar.gz" file then
            pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "make-" file)
          else
            null;

        include = version: builtins.match "[0-9].*" version != null;
      };
    };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
