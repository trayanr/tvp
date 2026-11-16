{ tvp, ... }:
let
  pname = "rustc";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-1.97.1.nix;
        deps = {
          runtimeLibc = tvp.packages.glibc_2;
          runtimeCompiler = tvp.packages.gcc_16;
          zlib = tvp.packages.zlib_1;
        };
        blob = {
          reason = "Upstream's binary distribution. rustc is self-hosting and TVP has no Rust chain, so there is nothing in the catalogue that could compile it.";
          needs = "A from-source chain: mrustc (C++, reaches ~1.54) and then a walk forward, or a period rustc able to build this one. Until then this package exists only for the platforms upstream publishes a binary for, which is what bounds the architectures TVP can serve.";
          blocked.package = "rustc-from-source";
        };
      };
      releases."1.97.1" = "sha256-tM28fMaw7gomZrGHJ2n9sq2Dk7KLY5UvZJO0tADkgys=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta = {
      upstream = {
        # static.rust-lang.org/dist/ is an S3 bucket with no listing (416), so
        # releases are read from the repository's tags instead.
        type = "git-tags";
        url = "https://github.com/rust-lang/rust";

        normalise = tag: tag;

        include = version: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" version != null;
      };
    };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://static.rust-lang.org/dist/rust-${version}-x86_64-unknown-linux-gnu.tar.gz";
        inherit sha256;
        name = "rust-${version}-x86_64-unknown-linux-gnu.tar.gz";
      };
    tests = import ./tests/installed.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.rustc = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
