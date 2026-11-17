{ tvp, ... }:
let
  pname = "flutter";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {

          dart = tvp.lib.packages.withConstraint {
            category = "artifact";
            reason = "Matched released SDK/toolchain payload or profile test artifact; changing its release changes the declared artifact identity.";
          } tvp.canonical.dart_3_13_7;
          git = tvp.packages.git_2;
          curl = tvp.packages.curl_8;
          gradle = tvp.packages.gradle_9;
          androidSdk = tvp.android.profiles.flutter;
          jdk = tvp.packages.jdk_21;
          ca-certificates = tvp.packages.ca-certificates;
          unzip = tvp.packages.unzip;
          which = tvp.packages.which;
          runtimeLibc = tvp.packages.glibc_2;
          runtimeCompiler = tvp.packages.gcc_16;
        };
        blob = {
          reason = "Flutter framework and command snapshot are built from the pinned SDK's Dart sources using source-built Dart. The matching upstream engine, frontend snapshots and web artifacts remain precompiled.";
          needs = "Source Flutter engine and engine artifact builds, plus their dependency graphs.";
          blocked.package = "flutter-engine-from-source";
        };
      };
      releases."3.47.8" = "sha256-uvfcxaPbumD+hjv0k6bPIDGVYh93huqlobugLNDYfdI=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/";
      archive = "flutter_linux_{version}-stable.tar.xz";
      discovery = null;
    };
    tests = import ./tests/installed.nix;
    testDeps = { };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."flutter" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
