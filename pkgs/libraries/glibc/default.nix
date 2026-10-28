{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.39" = {
      builder = ./build-2.39.nix;
      base = tvp.bases.gcc13;
      deps = {
        gcc = tvp.variants.gcc13.gcc_13_3_0;
        binutils = tvp.variants.gcc13.binutils_2_42;
        linuxHeaders = tvp.variants.gcc13."linux-headers_6_9";
        perl = tvp.variants.gcc13.perl_5_44_0;
        bison = tvp.variants.gcc13.bison_3_8_2;
        python3Minimal = tvp.variants.gcc13."python-minimal_3_12_5";
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
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
      inherit (tvpLib) platforms;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }: glibc: import ./tests { inherit pkgs tvpLib glibc; }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = tvp.bases.gcc13;
        versions."2.39" = {
          deps = {
            binutils = tvp.variants.gcc13.binutils_2_42;
            bison = tvp.variants.gcc13.bison_3_8_2;
            gcc = tvp.variants.gcc13.gcc_13_3_0;
            linuxHeaders = tvp.variants.gcc13.linux-headers_6_9;
            perl = tvp.variants.gcc13.perl_5_44_0;
            python3Minimal = tvp.variants.gcc13.python-minimal_3_12_5;
          };
        };
      };
    }
  );

in
{
  inherit canonical variants;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
