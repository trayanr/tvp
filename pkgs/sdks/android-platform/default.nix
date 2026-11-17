{ tvp, ... }:
let
  pname = "android-platform";
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
        };
        opts = {
          sourceLayout = {
            url = "https://dl.google.com/android/repository/platform-36_r02.zip";
            archiveRoot = "android-36";
            packageMetadata = ./metadata-36-r2.xml;
          };
          installedInterface = {
            sdkPath = "platforms/android-36";
            apiLevel = "36";
          };
        };
        blob = {
          reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
          needs = "A source Android toolchain and component build graph.";
          blocked.package = "android-sdk-from-source";
        };
      };
      releases."36-r2" = "sha256-N2BzaaKMW2QLOnmYho1FiY68t3dWWg6F+azzbyljHS4=";
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
        };
        opts = {
          sourceLayout = {
            url = "https://dl.google.com/android/repository/platform-36.1_r01.zip";
            archiveRoot = "android-36.1";
            packageMetadata = ./metadata-36.1-r1.xml;
          };
          installedInterface = {
            sdkPath = "platforms/android-36.1";
            apiLevel = "36.1";
          };
        };
        blob = {
          reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
          needs = "A source Android toolchain and component build graph.";
          blocked.package = "android-sdk-from-source";
        };
      };
      releases."36.1-r1" = "sha256-Jl6ap9jbar560WlghdXWJ4SzQQhMYl3kbbUwlwsegG0=";
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
        };
        opts = {
          sourceLayout = {
            url = "https://dl.google.com/android/repository/platform-37.0_r02.zip";
            archiveRoot = "android-37.0";
            packageMetadata = ./metadata-37.0-r2.xml;
          };
          installedInterface = {
            sdkPath = "platforms/android-37.0";
            apiLevel = "37.0";
          };
        };
        blob = {
          reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
          needs = "A source Android toolchain and component build graph.";
          blocked.package = "android-sdk-from-source";
        };
      };
      releases."37.0-r2" = "sha256-hAsj6Cf5bmSupMiaEZSqw9xfa6037bIxxceV2JAzDo0=";
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
        };
        opts = {
          sourceLayout = {
            url = "https://dl.google.com/android/repository/platform-37.1_r01.zip";
            archiveRoot = "android-37.1";
            packageMetadata = ./metadata-37.1-r1.xml;
          };
          installedInterface = {
            sdkPath = "platforms/android-37.1";
            apiLevel = "37.1";
          };
        };
        blob = {
          reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
          needs = "A source Android toolchain and component build graph.";
          blocked.package = "android-sdk-from-source";
        };
      };
      releases."37.1-r1" = "sha256-yt8KVBhHgg6j2P/FwZJWKhg3bPm6UQv5ZZx3L5pEIYQ=";
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
        };
        opts = {
          sourceLayout = {
            url = "https://dl.google.com/android/repository/platform-37.2_r02.zip";
            archiveRoot = "android-37.2";
            packageMetadata = ./metadata-37.2-r2.xml;
          };
          installedInterface = {
            sdkPath = "platforms/android-37.2";
            apiLevel = "37.2";
          };
        };
        blob = {
          reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
          needs = "A source Android toolchain and component build graph.";
          blocked.package = "android-sdk-from-source";
        };
      };
      releases."37.2-r2" = "sha256-F6+Y7BQnof7Z6ieBhKunHlO4fsoQNlVgL5/GTvEepNM=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: versionTable.${version}.def.opts.sourceLayout.url;
      discovery = {
        type = "android-repository";
        scope = "Published SDK repository index; superseded revisions may be absent.";
        url = "https://dl.google.com/android/repository/repository2-3.xml";
        packagePrefix = "platforms;android-";
        versionScheme = "platform";
      };
    };
    tests = import ./tests/installed.nix;
    testDeps = {
      jdk = tvp.packages.jdk_21;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."android-platform" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
