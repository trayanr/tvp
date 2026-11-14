{ pkgs, tvp }:
let
  retained = (import ./legacy.nix { inherit pkgs tvp; }).recipes.android-build-tools;
  pname = "android-build-tools";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          runtimeLibc = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Exact earlier source-GNU host libc selected by the released SDK adapter; preserve this generation independently of public compiler aliases.";
          } tvp.baseTiers.full.compiler.libc;
          runtimeCompiler = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Exact earlier source-GNU host compiler runtime selected by the released SDK adapter; preserve its overridable runtime-payload role.";
          } tvp.baseTiers.full.compiler.tvp.deps.compiler;
          unzip = tvp.packages.unzip;
          jdk = retained.versionTable."36.0.0".def.deps.jdk;
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
          } tvp.baseTiers.full.compiler.libc;
          runtimeCompiler = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Exact earlier source-GNU host compiler runtime selected by the released SDK adapter; preserve its overridable runtime-payload role.";
          } tvp.baseTiers.full.compiler.tvp.deps.compiler;
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
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = versionTable.${version}.def.opts.sourceLayout.url;
        inherit sha256;
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
  recipes."android-build-tools" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
