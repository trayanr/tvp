{ pkgs, tvp }:
let
  pname = "c-client";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps.openssl = tvp.packages.openssl_3;
        patches = [
          {
            file = ./openssl-hostname-verification.patch;
            reason = "Use OpenSSL hostname verification with opaque X509 types (Debian #828589).";
          }
          {
            file = ./order-generated-sources.patch;
            reason = "Generate c-client sources and flags before parallel compilation and use the selected libc headers.";
          }
        ];
      };
      releases."2007f" = "sha256-oyb9/mBcNpBLH4XSRQp2k+zLPzFi7ouyHqIWQHJrP+w=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://codeload.github.com/uw-imap/imap/tar.gz/refs/tags/imap-${version}_upstream";
      discovery = {
        type = "git-tags";
        url = "https://github.com/uw-imap/imap.git";
        normalise = tvp.lib.versions.fromArchiveName {
          prefix = "imap-";
          suffixes = [ "_upstream" ];
        };
      };
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
