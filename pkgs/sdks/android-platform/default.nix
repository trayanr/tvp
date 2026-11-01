{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "36-r2" = {
      builder = ./build-36-r2.nix;
      base = tvp.bases.default;
      deps = {
        unzip = tvp.packages.unzip;
      };
      opts = {
        url = "https://dl.google.com/android/repository/platform-36_r02.zip";
        sdkPath = "platforms/android-36";
        packageMetadata = ./metadata-36-r2.xml;
        apiLevel = "36";
      };
      blob = {
        reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
        needs = "A source Android toolchain and component build graph.";
        blocked.package = "android-sdk-from-source";
      };
    };
    "36.1-r1" = {
      builder = ./build-36-r2.nix;
      base = tvp.bases.default;
      deps = {
        unzip = tvp.packages.unzip;
      };
      opts = {
        url = "https://dl.google.com/android/repository/platform-36.1_r01.zip";
        sdkPath = "platforms/android-36.1";
        packageMetadata = ./metadata-36.1-r1.xml;
        apiLevel = "36.1";
      };
      blob = {
        reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
        needs = "A source Android toolchain and component build graph.";
        blocked.package = "android-sdk-from-source";
      };
    };
    "37.0-r2" = {
      builder = ./build-36-r2.nix;
      base = tvp.bases.default;
      deps = {
        unzip = tvp.packages.unzip;
      };
      opts = {
        url = "https://dl.google.com/android/repository/platform-37.0_r02.zip";
        sdkPath = "platforms/android-37.0";
        packageMetadata = ./metadata-37.0-r2.xml;
        apiLevel = "37.0";
      };
      blob = {
        reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
        needs = "A source Android toolchain and component build graph.";
        blocked.package = "android-sdk-from-source";
      };
    };
    "37.1-r1" = {
      builder = ./build-36-r2.nix;
      base = tvp.bases.default;
      deps = {
        unzip = tvp.packages.unzip;
      };
      opts = {
        url = "https://dl.google.com/android/repository/platform-37.1_r01.zip";
        sdkPath = "platforms/android-37.1";
        packageMetadata = ./metadata-37.1-r1.xml;
        apiLevel = "37.1";
      };
      blob = {
        reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
        needs = "A source Android toolchain and component build graph.";
        blocked.package = "android-sdk-from-source";
      };
    };
    "37.2-r2" = {
      builder = ./build-36-r2.nix;
      base = tvp.bases.default;
      deps = {
        unzip = tvp.packages.unzip;
      };
      opts = {
        url = "https://dl.google.com/android/repository/platform-37.2_r02.zip";
        sdkPath = "platforms/android-37.2";
        packageMetadata = ./metadata-37.2-r2.xml;
        apiLevel = "37.2";
      };
      blob = {
        reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
        needs = "A source Android toolchain and component build graph.";
        blocked.package = "android-sdk-from-source";
      };
    };
  };
  pname = "android-platform";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."36-r2";
      releases."36-r2" = "sha256-N2BzaaKMW2QLOnmYho1FiY68t3dWWg6F+azzbyljHS4=";
    }
    {
      def = defs."36.1-r1";
      releases."36.1-r1" = "sha256-Jl6ap9jbar560WlghdXWJ4SzQQhMYl3kbbUwlwsegG0=";
    }
    {
      def = defs."37.0-r2";
      releases."37.0-r2" = "sha256-hAsj6Cf5bmSupMiaEZSqw9xfa6037bIxxceV2JAzDo0=";
    }
    {
      def = defs."37.1-r1";
      releases."37.1-r1" = "sha256-yt8KVBhHgg6j2P/FwZJWKhg3bPm6UQv5ZZx3L5pEIYQ=";
    }
    {
      def = defs."37.2-r2";
      releases."37.2-r2" = "sha256-F6+Y7BQnof7Z6ieBhKunHlO4fsoQNlVgL5/GTvEepNM=";
    }
  ];
  testDeps = {
    jdk = tvp.packages.jdk_21;
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
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
        jdk = package.tvp.declaredTestDependencies.jdk;
      };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
