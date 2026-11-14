{ pkgs, tvp }:
let
  retained = (import ./legacy.nix { inherit pkgs tvp; }).recipes.android-commandline-tools;
  pname = "android-commandline-tools";
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
          jdk = tvp.packages.jdk_21;
          androidCli = tvp.lib.packages.withConstraint {
            category = "artifact";
            reason = "Matched pinned Android CLI payload for the released command-line tools.";
          } tvp.canonical.android-cli_1_1_16717390;
        };
        opts = {
          sourceLayout = {
            url = "https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip";
          };
        };
        blob = {
          reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
          needs = "A source Android toolchain and component build graph.";
          blocked.package = "android-sdk-from-source";
        };
      };
      releases."23.0" = "sha256-CHeh0Ej+SiTv4u/1NspCI/et61hki7gZCdM8RGkYz6g=";
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
  recipes."android-commandline-tools" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
