{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          pkg-config = tvp.packages.pkg-config;
          openssl = tvp.packages.openssl;
          zlib = tvp.packages.zlib_1;
          dnssd = tvp.packages.libdns_sd;
        };
        patches = [
          {
            file = ./patches/testfile-explicit-search-path.patch;
            reason = "Upstream file tests assume /bin/cat. Keep single-directory and path-list searches against explicitly declared sandbox Coreutils.";
          }
        ];
      };
      releases."2.4.20" = "sha256-q02c1/PlgGAJHSsklyIj1kAWdfEcSbZav09u8x3qIv8=";
    }
  ];
  pname = "libcups";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://github.com/OpenPrinting/cups/releases/download/v${version}/cups-${version}-source.tar.gz";
        inherit sha256;
      };
    tests = import ./tests/owned.nix;

  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libcups = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
