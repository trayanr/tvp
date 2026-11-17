{ tvp, ... }:
let
  pname = "android-ndk";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-r28.nix;
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
          zlib = tvp.packages.zlib_1;
          gnumake = tvp.packages.gnumake;
        };
        opts = {
          sourceLayout = {
            url = "https://dl.google.com/android/repository/android-ndk-r28c-linux.zip";
          };
        };
        blob = {
          reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
          needs = "A source Android toolchain and component build graph.";
          blocked.package = "android-sdk-from-source";
        };
      };
      releases."28.2.13676358" = "sha256-37INOW3yjKAqjHCDFLgUpNlh3JB0+aFhkydG+BWqVS8=";
    }
    {
      def = {
        builder = ./build-r30.nix;
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
          zlib = tvp.packages.zlib_1;
          gnumake = tvp.packages.gnumake;
        };
        opts = {
          sourceLayout = {
            url = "https://dl.google.com/android/repository/android-ndk-r30-linux.zip";
          };
        };
        blob = {
          reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
          needs = "A source Android toolchain and component build graph.";
          blocked.package = "android-sdk-from-source";
        };
      };
      releases."30.0.16248370" = "sha256-dTYR9BDQAs/NPz3C70mq1TIInTGAtDbAYKkL8Py2TfI=";
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
    testDeps = { };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."android-ndk" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
