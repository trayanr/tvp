{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "37.0.1" = {
      builder = ./build-37.0.1.nix;
      base = tvp.bases.default;
      deps = {
        unzip = tvp.packages.unzip;
        patchelf = tvp.packages.patchelf;
        bash = tvp.packages.bash_5;
      };
      opts = {
        url = "https://dl.google.com/android/repository/platform-tools_r37.0.1-linux.zip";
        sdkPath = "platform-tools";
        packageMetadata = ./metadata-37.0.1.xml;
        inherit (platform) dynamicLinker;
      };
      blob = {
        reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
        needs = "A source Android toolchain and component build graph.";
        blocked.package = "android-sdk-from-source";
      };
    };
  };
  pname = "android-platform-tools";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."37.0.1";
      releases."37.0.1" = "sha256-0jDxOEL2D3gqhkX5yBP4+EW/NgiepyifKMSPF5eTE/E=";
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
