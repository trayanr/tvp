{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "1.97.1" = {
      builder = ./build-1.97.1.nix;
      base = tvp.bases.default;
      deps.patchelf = tvp.packages.patchelf;
      opts = {
        inherit (platform) dynamicLinker;
        triple = platform.config;
      };
      blob = {
        reason = "Cargo component of the pinned upstream Rust binary distribution; needed to build vendored Rust dependencies before TVP has a source Cargo bootstrap chain.";
        needs = "Source-built Cargo and a source Rust compiler bootstrap chain.";
        blocked.package = "cargo-from-source";
      };
    };
  };
  pname = "cargo-bootstrap";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.97.1";
      releases."1.97.1" = "sha256-tM28fMaw7gomZrGHJ2n9sq2Dk7KLY5UvZJO0tADkgys=";
    }
  ];
  testDeps = {
    rustc = (
      tvpLib.packages.withConstraint {
        category = "construction";
        reason = "Retained complete Rust seed generation; historical construction and tests must not follow the promoted public provider.";
      } (import ../../compilers/rust/legacy.nix { inherit pkgs tvp; }).canonical.rustc_1_97_1
    );
  };
  packageArgs = {
    inherit testDeps;
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
        rustc = package.tvp.declaredTestDependencies.rustc;
      }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  inherit canonical packageArgs;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
