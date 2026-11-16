{ tvp, ... }:
let
  pname = "ca-certificates";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-2026-10-20-current.nix;
      };
      releases = {
        "2026-10-20" = "sha256-eW8Tib/qE8DtePZjt2W6r/VKUI5Ug3hr1uznPF4+PL4=";
      };
    }
  ];
  testDeps = {
    diffutils = tvp.packages.diffutils;
    openssl = tvp.packages.openssl_4;
    grep = tvp.packages.gnugrep;
    findutils = tvp.packages.findutils;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://curl.se/ca/cacert-${version}.pem";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."ca-certificates" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
