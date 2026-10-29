{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "3.47.8" = {
      builder = ./build-3.47.8.nix;
      base = tvp.bases.default;
      deps = {
        dart = tvp.packages.dart_3_13_7;
        git = tvp.packages.git_2_56_0;
        curl = tvp.packages.curl_8_23_0;
        gradle = tvp.packages.gradle_9_3_1;
        androidSdk = tvp.android.profiles.flutter;
        jdk = tvp.packages.jdk_21_0_13;
        ca-certificates = tvp.packages.ca-certificates_2026_10_20;
        bash = tvp.packages.bash_5_2_37;
        coreutils = tvp.packages.coreutils_9_5;
        findutils = tvp.packages.findutils_4_10_0;
        gnugrep = tvp.packages.gnugrep_3_11;
        gnused = tvp.packages.gnused_4_9;
        gawk = tvp.packages.gawk_5_4_1;
        gnutar = tvp.packages.gnutar_1_35;
        gzip = tvp.packages.gzip_1_13;
        xz = tvp.packages.xz_5_8_1;
        unzip = tvp.packages.unzip_6_0;
        python = tvp.packages.python_3_12_16;
        patchelf = tvp.packages.patchelf_0_19_2;
        which = tvp.packages.which_2_21;
      };
      opts = {
        inherit (platform) dynamicLinker;
      };
      blob = {
        reason = "Flutter framework and command snapshot are built from the pinned SDK's Dart sources using source-built Dart. The matching upstream engine, frontend snapshots and web artifacts remain precompiled.";
        needs = "Source Flutter engine and engine artifact builds, plus their dependency graphs.";
        blocked.package = "flutter-engine-from-source";
      };
    };
  };
  pname = "flutter";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.47.8";
      releases."3.47.8" = "sha256-uvfcxaPbumD+hjv0k6bPIDGVYh93huqlobugLNDYfdI=";
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
