{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps.pkgConfig = tvp.packages.pkg-config;
      };
      releases = {
        "10.44" = "sha256-008C4RPPcZOh6/J3DTrFJwiNSF1OBH7RDl0hfG713pY=";
        "10.47" = "sha256-R/6MmUYSUNQviebo/a66naBXhV0G63/AjZygP9CNe8c=";
        "10.48" = "sha256-tsaP3286wxOItQqon/D8ScAMmHwW57UUZJHRIAPyyO0=";
        "10.49" = "sha256-U8FW4bpBaiDajmU5XaoTLaDYDnaRBCTKyj/Nrngx04Q=";
      };
    }
  ];
  pname = "pcre2";

  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${version}/pcre2-${version}.tar.bz2";
      discovery = import ./upstream.nix;
    };
    tests = import ./tests/installed.nix;
    testDeps.perl = tvp.packages.perl_5;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.pcre2 = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
