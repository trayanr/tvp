{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "36.0.0" = {
      builder = ./build-36.0.0.nix;
      base = tvp.bases.default;
      deps = {
        unzip = tvp.packages.unzip_6_0;
        patchelf = tvp.packages.patchelf_0_19_2;
        bash = tvp.packages.bash_5_2_37;
        jdk = tvp.packages.jdk_21_0_13;
      };
      opts = {
        url = "https://dl.google.com/android/repository/build-tools_r36_linux.zip";
        sdkPath = "build-tools/36.0.0";
        packageMetadata = ./metadata-36.0.0.xml;
        inherit (platform) dynamicLinker;
      };
      blob = {
        reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
        needs = "A source Android toolchain and component build graph.";
        blocked.package = "android-sdk-from-source";
      };
    };
    "37.0.0" = {
      builder = ./build-36.0.0.nix;
      base = tvp.bases.default;
      deps = {
        unzip = tvp.packages.unzip_6_0;
        patchelf = tvp.packages.patchelf_0_19_2;
        bash = tvp.packages.bash_5_2_37;
        jdk = tvp.packages.jdk_21_0_13;
      };
      opts = {
        url = "https://dl.google.com/android/repository/build-tools_r37_linux.zip";
        sdkPath = "build-tools/37.0.0";
        packageMetadata = ./metadata-37.0.0.xml;
        inherit (platform) dynamicLinker;
      };
      blob = {
        reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
        needs = "A source Android toolchain and component build graph.";
        blocked.package = "android-sdk-from-source";
      };
    };
  };
  pname = "android-build-tools";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."36.0.0";
      releases."36.0.0" = "sha256-XZrHf7b/Q9naUYoze0/Pj5CXET31Mdmczv6A73zoJQs=";
    }
    {
      def = defs."37.0.0";
      releases."37.0.0" = "sha256-Aa8Xk0fLzZwgi3+BcfeyH23R0vhbzRXojKpR1de4YGA=";
    }
  ];
  testDeps = {
    platform = tvp.packages.android-platform_36_r2;
    zip = tvp.packages.zip_3_0;
  };
  canonical = tvpLib.packages.mkVersions {
    inherit testDeps;
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        platform = testDeps.platform;
        zip = testDeps.zip;
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
