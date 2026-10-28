{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "13.3.0" = {
      builder = ./build-13.3.nix;
      base = tvp.bases.gcc13;
      # Upstream libcpp uses nonliteral diagnostics with no format arguments.
      opts.hardeningDisable = [ "format" ];
      deps = {
        binutils = tvp.variants.gcc13.binutils_2_42;
        gmp = tvp.variants.gcc13.gmp_6_3_0;
        mpfr = tvp.variants.gcc13.mpfr_4_2_1;
        mpc = tvp.variants.gcc13.mpc_1_3_1;
        isl = tvp.variants.gcc13.isl_0_20;
        zlib = tvp.variants.gcc13.zlib_1_3_2;
        zstd = tvp.variants.gcc13.zstd_1_5_6;
        libxcrypt = tvp.variants.gcc13.libxcrypt_4_4_36;
        perl = tvp.variants.gcc13.perl_5_44_0;
        texinfo = tvp.variants.gcc13.texinfo_7_1;
        which = tvp.variants.gcc13.which_2_21;
        # The first compiler needs a libc from its explicit bootstrap parent.
        glibc = tvp.bases.gcc13.stdenv.cc.libc;
      };
      patches = [
        {
          file = ./patches/program-prefix.patch;
          reason = "Store-layout adaptation: let GCC's explicit -B prefixes select the assembler and program queries before the configured absolute fallback. This makes the base's selected binutils real, rather than silently using the compiler's bootstrap assembler.";
        }
        {
          file = ./patches/linker-prefix.patch;
          reason = "Store-layout adaptation: let collect2 find the linker from GCC's explicit -B/COMPILER_PATH before the configured absolute fallback, so a base can select its libc/linker wrapper. Without this, -print-prog-name=ld reports the wrapper but collect2 invokes the raw linker.";
        }
        {
          file = ./patches/no-system-dirs.patch;
          reason = "Store-layout adaptation: remove implicit /usr/local/include, /lib and /usr/lib searches. Headers and startup objects are named by the toolchain. From nixpkgs 12228ff1752d7b7624a54e9c1af4b222b3c1073b, gcc-12-no-sys-dirs.patch.";
        }
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."13.3.0";
      releases."13.3.0" = "sha256-CEXpYhyVQ6E/SE6UWEpJ/8ASmXDpkUYkI1/B0GGgwIM=";
    }
  ];
  pname = "gcc";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
      inherit (tvpLib) platforms;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }: gcc: import ./tests { inherit pkgs tvpLib gcc; }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = tvp.bases.gcc13;
        versions."13.3.0" = {
          deps = {
            binutils = tvp.variants.gcc13.binutils_2_42;
            gmp = tvp.variants.gcc13.gmp_6_3_0;
            isl = tvp.variants.gcc13.isl_0_20;
            libxcrypt = tvp.variants.gcc13.libxcrypt_4_4_36;
            mpc = tvp.variants.gcc13.mpc_1_3_1;
            mpfr = tvp.variants.gcc13.mpfr_4_2_1;
            perl = tvp.variants.gcc13.perl_5_44_0;
            texinfo = tvp.variants.gcc13.texinfo_7_1;
            which = tvp.variants.gcc13.which_2_21;
            zlib = tvp.variants.gcc13.zlib_1_3_2;
            zstd = tvp.variants.gcc13.zstd_1_5_6;
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
