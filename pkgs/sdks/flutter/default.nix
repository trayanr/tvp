{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "3.47.8" = {
      builder = ./build-3.47.8.nix;
      base = tvp.bases.default;
      deps = {
        dart = (
          tvp.lib.packages.withConstraint {
            category = "artifact";
            reason = "Matched released SDK/toolchain payload or profile test artifact; changing its release changes the declared artifact identity.";
          } tvp.canonical.dart_3_13_7
        );
        git = tvp.packages.git_2;
        curl = tvp.packages.curl_8;
        gradle = tvp.packages.gradle_9;
        androidSdk = tvp.android.profiles.flutter;
        jdk = tvp.packages.jdk_21;
        ca-certificates = tvp.packages.ca-certificates;
        bash = tvp.packages.bash_5;
        coreutils = tvp.packages.coreutils;
        findutils = tvp.packages.findutils;
        gnugrep = tvp.packages.gnugrep;
        gnused = tvp.packages.gnused;
        gawk = tvp.packages.gawk;
        gnutar = tvp.packages.gnutar;
        gzip = tvp.packages.gzip;
        xz = tvp.packages.xz_5;
        unzip = tvp.packages.unzip;
        python = tvp.packages.python_3;
        patchelf = tvp.packages.patchelf;
        which = tvp.packages.which;
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
