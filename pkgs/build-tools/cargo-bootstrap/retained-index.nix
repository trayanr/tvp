{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  retained = (import ./legacy.nix { inherit pkgs tvp; }).packageArgs;
  candidate = import ../../../bases/source-gnu { };
  selectedTool =
    role: provider:
    if provider ? __tvpSelection then
      provider
    else
      tvpLib.packages.tagSelection {
        namespace = "source-gnu.inputs";
        selector = role;
        kind = "source-base-build-tool";
        reason = "Explicit retained source-GNU tool for binary provider installation or finalization.";
      } provider;
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  definition =
    (tvpLib.packages.mkDefs {
      "1.97.1" = {
        constructor = tvp.builder;
        builder = ./native/build-1.97.1.nix;
        base = candidate.base;
        helpers = {
          inherit tvp;
        };
        testContext =
          package:
          tvpLib.tests.fromPackage {
            builder = tvp.builder;
            inherit package;
          };
        source =
          { version, sha256 }:
          import <nix/fetchurl.nix> {
            url = "https://static.rust-lang.org/dist/rust-${version}-x86_64-unknown-linux-gnu.tar.gz";
            name = "rust-${version}-x86_64-unknown-linux-gnu.tar.gz";
            inherit sha256;
          };
        deps =
          (pkgs.lib.mapAttrs selectedTool {
            # Explicit source-owned tools; tag otherwise unlabelled bootstrap roles.
            inherit (candidate.tools)
              bash
              coreutils
              python
              binutils
              patchelf
              tar
              gzip
              sed
              grep
              gawk
              findutils
              ;
          })
          // {
            runtimeLibc = tvp.packages.glibc_2;
            runtimeCompiler = tvp.packages.gcc_16;
          };
        blob = retained.versionTable."1.97.1".def.blob;
      };
    })."1.97.1";
  versionTable = retained.versionTable // {
    "1.97.1" = retained.versionTable."1.97.1" // {
      def = if native then definition else retained.versionTable."1.97.1".def;
    };
  };
  publicArgs = retained // {
    infra = if native then { inherit (pkgs) lib; } else retained.infra;
    inherit versionTable;
    testDeps.rustc = tvp.packages.rustc_1;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix { inherit package; }
      else
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  pname = "cargo-bootstrap";
  canonical = tvpLib.packages.mkVersions publicArgs;
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
