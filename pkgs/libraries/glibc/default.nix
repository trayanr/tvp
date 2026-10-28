{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.39" = {
      builder = ./build-2.39.nix;
      base = tvp.bases.default;
      deps = {
        gcc = tvp.packages.gcc_13_3_0;
        binutils = tvp.packages.binutils_2_42;
        linuxHeaders = tvp.packages."linux-headers_6_9";
        perl = tvp.packages.perl_5_44_0;
        # Build-time bootstrap inputs; neither is a runtime base input.
        inherit (pkgs) bison python3Minimal;
      };
      patches = [
        {
          file = ./patches/store-cache.patch;
          reason = "Store-layout adaptation: resolve ld.so.cache and ld.so.conf inside this glibc's prefix instead of the host /etc. From nixpkgs 12228ff1752d7b7624a54e9c1af4b222b3c1073b, dont-use-system-ld-so-cache.patch; no stable-branch fixes applied.";
        }
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.39";
      releases."2.39" = "sha256-93vUfPgXDFc2Wue/hmlsEYrbOxINMlnGTFAtPcHi2SY=";
    }
  ];
  pname = "glibc";
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = glibc: import ./tests { inherit pkgs tvpLib glibc; };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
