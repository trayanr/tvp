{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "28.2.13676358" = {
      builder = ./build-28.2.13676358.nix;
      base = tvp.bases.default;
      deps = {
        unzip = tvp.packages.unzip_6_0;
        patchelf = tvp.packages.patchelf_0_19_2;
        bash = tvp.packages.bash_5_2_37;
        zlib = tvp.packages.zlib_1_3_2;
        gnumake = tvp.packages.gnumake_4_4_1;
      };
      opts = {
        url = "https://dl.google.com/android/repository/android-ndk-r28c-linux.zip";
        sdkPath = "ndk/28.2.13676358";
        packageMetadata = ./metadata-28.2.13676358.xml;
        inherit (platform) dynamicLinker;
      };
      blob = {
        reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
        needs = "A source Android toolchain and component build graph.";
        blocked.package = "android-sdk-from-source";
      };
    };
    "30.0.16248370" = {
      builder = ./build-28.2.13676358.nix;
      base = tvp.bases.default;
      deps = {
        unzip = tvp.packages.unzip_6_0;
        patchelf = tvp.packages.patchelf_0_19_2;
        bash = tvp.packages.bash_5_2_37;
        zlib = tvp.packages.zlib_1_3_2;
        gnumake = tvp.packages.gnumake_4_4_1;
      };
      opts = {
        url = "https://dl.google.com/android/repository/android-ndk-r30-linux.zip";
        sdkPath = "ndk/30.0.16248370";
        packageMetadata = ./metadata-30.0.16248370.xml;
        inherit (platform) dynamicLinker;
      };
      blob = {
        reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
        needs = "A source Android toolchain and component build graph.";
        blocked.package = "android-sdk-from-source";
      };
    };
  };
  pname = "android-ndk";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."28.2.13676358";
      releases."28.2.13676358" = "sha256-37INOW3yjKAqjHCDFLgUpNlh3JB0+aFhkydG+BWqVS8=";
    }
    {
      def = defs."30.0.16248370";
      releases."30.0.16248370" = "sha256-dTYR9BDQAs/NPz3C70mq1TIInTGAtDbAYKkL8Py2TfI=";
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
