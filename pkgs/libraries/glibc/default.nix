{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.39" = {
      builder = ./build-2.39.nix;
      base = tvp.bases.default;
      deps = {
        gcc = tvp.packages.gcc_13;
        binutils = tvp.packages.binutils_2;
        linuxHeaders = tvp.packages.linux-headers_6;
        perl = tvp.packages.perl_5;
        bison = tvp.packages.bison;
        python3Minimal = tvp.packages.python-minimal_3;
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

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
