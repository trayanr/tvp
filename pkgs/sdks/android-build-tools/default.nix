{ tvp, ... }:
let
  pname = "android-build-tools";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          runtimeLibc = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Exact earlier source-GNU host libc selected by the released SDK adapter; preserve this generation independently of public compiler aliases.";
          } tvp.bases.gcc_16.full.compiler.libc;
          runtimeCompiler = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Exact earlier source-GNU host compiler runtime selected by the released SDK adapter; preserve its overridable runtime-payload role.";
          } tvp.bases.gcc_16.full.compiler.cc;
          unzip = tvp.packages.unzip;
          jdk = tvp.lib.packages.withConstraint {
            reason = "Exact JDK21 provider of the released Android36 SDK profile; keep its launcher/runtime selection explicit.";
          } tvp.packages.jdk_21_0_13;
        };
        opts = {
          sourceLayout = {
            url = "https://dl.google.com/android/repository/build-tools_r36_linux.zip";
            archiveRoot = "android-16";
            packageMetadata = ./metadata-36.0.0.xml;
          };
          installedInterface = {
            sdkPath = "build-tools/36.0.0";
          };
        };
        blob = {
          reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
          needs = "A source Android toolchain and component build graph.";
          blocked.package = "android-sdk-from-source";
        };
      };
      releases."36.0.0" = "sha256-XZrHf7b/Q9naUYoze0/Pj5CXET31Mdmczv6A73zoJQs=";
    }
    {
      def = {
        builder = ./build.nix;
        deps = {
          runtimeLibc = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Exact earlier source-GNU host libc selected by the released SDK adapter; preserve this generation independently of public compiler aliases.";
          } tvp.bases.gcc_16.full.compiler.libc;
          runtimeCompiler = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Exact earlier source-GNU host compiler runtime selected by the released SDK adapter; preserve its overridable runtime-payload role.";
          } tvp.bases.gcc_16.full.compiler.cc;
          unzip = tvp.packages.unzip;
          jdk = tvp.packages.jdk_21;
        };
        opts = {
          sourceLayout = {
            url = "https://dl.google.com/android/repository/build-tools_r37_linux.zip";
            archiveRoot = "android-37.0";
            packageMetadata = ./metadata-37.0.0.xml;
          };
          installedInterface = {
            sdkPath = "build-tools/37.0.0";
          };
        };
        blob = {
          reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
          needs = "A source Android toolchain and component build graph.";
          blocked.package = "android-sdk-from-source";
        };
      };
      releases."37.0.0" = "sha256-Aa8Xk0fLzZwgi3+BcfeyH23R0vhbzRXojKpR1de4YGA=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: versionTable.${version}.def.opts.sourceLayout.url;
    };
    tests = import ./tests/installed.nix;
    testDeps = {
      platform = (
        tvp.lib.packages.withConstraint {
          category = "artifact";
          reason = "Matched released SDK/toolchain payload or profile test artifact; changing its release changes the declared artifact identity.";
        } tvp.canonical."android-platform_36_r2"
      );
      zip = tvp.packages.zip;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."android-build-tools" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
