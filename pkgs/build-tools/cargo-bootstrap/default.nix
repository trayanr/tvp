{ tvp, ... }:
let
  pname = "cargo-bootstrap";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.97.1-current.nix;
        deps = {

          runtimeLibc = tvp.packages.glibc_2;
          runtimeCompiler = tvp.packages.gcc_16;
        };
        blob = {
          reason = "Cargo component of the pinned upstream Rust binary distribution; needed to build vendored Rust dependencies before TVP has a source Cargo bootstrap chain.";
          needs = "Source-built Cargo and a source Rust compiler bootstrap chain.";
          blocked.package = "cargo-from-source";
        };
      };
      releases = {
        "1.97.1" = "sha256-tM28fMaw7gomZrGHJ2n9sq2Dk7KLY5UvZJO0tADkgys=";
      };
    }
  ];
  testDeps = {
    rustc = tvp.packages.rustc_1;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://static.rust-lang.org/dist/rust-${version}-x86_64-unknown-linux-gnu.tar.gz";
        name = "rust-${version}-x86_64-unknown-linux-gnu.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."cargo-bootstrap" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
