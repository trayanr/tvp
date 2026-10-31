{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "1.97.1" = {
      builder = ./build-1.97.1.nix;
      base = tvp.bases.default;
      deps.patchelf = tvp.packages.patchelf_0_19_2;
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
    rustc = tvp.packages.rustc_1_97_1;
  };
  canonical = tvpLib.packages.mkVersions {
    inherit testDeps;
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
        rustc = testDeps.rustc;
      };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
