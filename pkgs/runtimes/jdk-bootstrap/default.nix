{ pkgs, tvp }:
let
  retained = (import ./legacy.nix { inherit pkgs tvp; }).packageArgs;
  pname = "jdk-bootstrap";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-21.0.13.nix;
        base = tvp.baseTiers.full;
        deps = {
          runtimeLibc = tvp.packages.glibc_2;
          runtimeCompiler = tvp.packages.gcc_16;
          zlib = tvp.packages.zlib_1;
          alsa = tvp.packages.alsa-lib_1;
          fontconfig = tvp.packages.fontconfig_2;
        };
        blob = {
          reason = "Explicit Temurin binary boot JDK for compiling the first owned OpenJDK source release.";
          needs = "A source Java bootstrap chain from a non-Java compiler seed.";
          blocked.package = "jdk-bootstrap-from-source";
        };
      };
      releases."21.0.13" = "sha256-1/XVz4ZaKQK3D/VJuXWGp9PyNOAW8EGrRH6nQMfWbRw=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta = retained.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${version}%2B9/OpenJDK21U-jdk_x64_linux_hotspot_${version}_9.tar.gz";
        name = "OpenJDK21U-jdk_x64_linux_hotspot_${version}_9.tar.gz";
        inherit sha256;
      };
    tests = (import ./tests/installed.nix);
    testDeps.fontArchive = tvp.lib.packages.tagSelection {
      namespace = "upstream-source-fixture";
      selector = "openjdk-21.0.13-ga-font";
      kind = "test-source";
      reason = "Pinned A.ttf fixture for the headless binary seed test; no source JDK build.";
    } (import ../jdk/legacy.nix { inherit pkgs tvp; }).canonical.jdk_21_0_13.src;
  };
  # Preserve only the historical named test-factory override, lazily.
  recipe = family // {
    extraArgs = family.extraArgs // {
      mkTests = import ./tests/caller-factory.nix { inherit pkgs tvp; };
    };
  };
  canonical = tvp.lib.packages.mkVersions recipe;
in
{
  recipes.jdk-bootstrap = recipe // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
