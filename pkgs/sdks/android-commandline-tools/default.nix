{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "23.0" = {
      builder = ./build-23.0.nix;
      base = tvp.bases.default;
      deps = {
        androidCli = tvp.packages.android-cli_1_1_16717390;
        unzip = tvp.packages.unzip_6_0;
        patchelf = tvp.packages.patchelf_0_19_2;
        bash = tvp.packages.bash_5_2_37;
        jdk = tvp.packages.jdk_21_0_13;
      };
      opts = {
        url = "https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip";
        sdkPath = "cmdline-tools/23.0";
        packageMetadata = ./metadata-23.0.xml;
        inherit (platform) dynamicLinker;
      };
      blob = {
        reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
        needs = "A source Android toolchain and component build graph.";
        blocked.package = "android-sdk-from-source";
      };
    };
  };
  pname = "android-commandline-tools";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."23.0";
      releases."23.0" = "sha256-CHeh0Ej+SiTv4u/1NspCI/et61hki7gZCdM8RGkYz6g=";
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
