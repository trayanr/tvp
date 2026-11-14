{ pkgs, tvp }:
let
  retained = (import ./legacy.nix { inherit pkgs tvp; }).recipes.android-platform-tools;
  pname = "android-platform-tools";
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
        };
        opts = {
          sourceLayout = {
            url = "https://dl.google.com/android/repository/platform-tools_r37.0.1-linux.zip";
          };
        };
        blob = {
          reason = "Pinned upstream Android SDK component distribution, with host tools adapted to the owned runtime.";
          needs = "A source Android toolchain and component build graph.";
          blocked.package = "android-sdk-from-source";
        };
      };
      releases."37.0.1" = "sha256-0jDxOEL2D3gqhkX5yBP4+EW/NgiepyifKMSPF5eTE/E=";
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
  recipes."android-platform-tools" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
