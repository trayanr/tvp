# Exact recipe selections used to construct the owned GCC 13 environment.
{
  pkgs,
  tvpLib,
  recipes,
  construction,
}:
tvpLib.packages.mergeVariants {
  gcc = tvpLib.packages.mkVariants (
    recipes.gcc
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."13.3.0" = {
          deps = {
            glibc = construction.bases.gcc13.stdenv.cc.libc;
            binutils = construction.variants.gcc13.binutils_2_42;
            gmp = construction.variants.gcc13.gmp_6_3_0;
            isl = construction.variants.gcc13.isl_0_20;
            libxcrypt = construction.variants.gcc13.libxcrypt_4_4_36;
            mpc = construction.variants.gcc13.mpc_1_3_1;
            mpfr = construction.variants.gcc13.mpfr_4_2_1;
            perl = construction.variants.gcc13.perl_5_44_0;
            texinfo = construction.variants.gcc13.texinfo_7_1;
            which = construction.variants.gcc13.which_2_21;
            zlib = construction.variants.gcc13.zlib_1_3_2;
            zstd = construction.variants.gcc13.zstd_1_5_6;
          };
        };
      };
    }
  );
}
