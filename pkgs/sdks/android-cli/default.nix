{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "1.1.16717390" = {
      builder = ./build-1.1.16717390.nix;
      base = tvp.bases.default;
      deps.patchelf = tvp.packages.patchelf_0_19_2;
      opts = {
        inherit (platform) dynamicLinker;
      };
      blob = {
        reason = "Pinned Android CLI executable; replaces the command-line tools launcher which otherwise downloads an unpinned latest binary.";
        needs = "A source build of Android CLI and its dependency graph.";
        blocked.package = "android-cli-from-source";
      };
    };
  };
  pname = "android-cli";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.1.16717390";
      releases."1.1.16717390" = "sha256-s07Quu7/oqruJyDYJJG5dYNWluLlaEBEkHi+yIVDZWQ=";
    }
  ];
  canonical = tvpLib.packages.mkVersions {
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
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
