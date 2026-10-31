# Construction never follows the public default it is building. These exact
# selections reproduce the reviewed GCC16 native three-stage producer on v3.
{
  pkgs,
  tvpLib,
  recipes,
  construction,
}:
let
  parent = construction.bases.gcc13-owned-v3;
  inputs = construction.variants.gcc16;
  select =
    recipe: versions:
    tvpLib.packages.mkVariants (
      recipe
      // {
        inherit pkgs;
        profiles.gcc16 = {
          base = parent;
          inherit versions;
        };
      }
    );
in
tvpLib.packages.mergeVariants {
  gcc = select recipes.gcc {
    "16.2.0" = {
      deps = {
        binutils = inputs.binutils_2_42;
        gmp = inputs.gmp_6_3_0;
        mpfr = inputs.mpfr_4_2_2;
        mpc = inputs.mpc_1_3_1;
        isl = inputs.isl_0_28;
        zlib = inputs.zlib_1_3_2;
        zstd = inputs.zstd_1_5_6;
        libxcrypt = inputs.libxcrypt_4_4_36;
        perl = inputs.perl_5_44_0;
        texinfo = inputs.texinfo_7_1;
        which = inputs.which_2_21;
        glibc = parent.stdenv.cc.libc;
      };
    };
  };
  binutils = select recipes.binutils {
    "2.42" = {
      deps = {
        bison = inputs.bison_3_8_2;
        perl = inputs.perl_5_44_0;
        pkg-config = inputs.pkg-config_0_29_2;
        texinfo = inputs.texinfo_7_1;
        zlib = inputs.zlib_1_3_2;
        zstd = inputs.zstd_1_5_6;
      };
    };
  };
  gmp = select recipes.gmp {
    "6.3.0" = {
      deps = {
        m4 = inputs.m4_1_4_21;
      };
    };
  };
  mpfr = select recipes.mpfr {
    "4.2.1" = {
      deps = {
        gmp = inputs.gmp_6_3_0;
      };
    };
    "4.2.2" = {
      deps = {
        gmp = inputs.gmp_6_3_0;
      };
    };
  };
  mpc = select recipes.mpc {
    "1.3.1" = {
      deps = {
        gmp = inputs.gmp_6_3_0;
        mpfr = inputs.mpfr_4_2_1;
      };
    };
  };
  isl = select recipes.isl {
    "0.28" = {
      deps = {
        gmp = inputs.gmp_6_3_0;
      };
    };
  };
  zlib = select recipes.zlib {
    "1.3.2" = { };
  };
  zstd = select recipes.zstd {
    "1.5.6" = {
      deps = {
        xz = inputs.xz_5_8_3;
        zlib = inputs.zlib_1_3_2;
      };
    };
  };
  libxcrypt = select recipes.libxcrypt {
    "4.4.36" = {
      deps = {
        perl = inputs.perl_5_44_0;
      };
    };
  };
  perl = select recipes.perl {
    "5.44.0" = { };
  };
  texinfo = select recipes.texinfo {
    "7.1" = {
      deps = {
        perl = inputs.perl_5_44_0;
        ncurses = inputs.ncurses_6_6;
        localeTools = parent.stdenv.cc.libc.bin;
      };
    };
  };
  which = select recipes.which {
    "2.21" = { };
  };
  m4 = select recipes.m4 {
    "1.4.21" = { };
  };
  pkg-config = select recipes.pkg-config {
    "0.29.2" = { };
  };
  bison = select recipes.bison {
    "3.8.2" = {
      deps = {
        m4 = inputs.m4_1_4_21;
        perl = inputs.perl_5_44_0;
      };
    };
  };
  ncurses = select recipes.ncurses {
    "6.6" = {
      deps = {
        pkg-config = inputs.pkg-config_0_29_2;
      };
    };
  };
  xz = select recipes.xz {
    "5.8.3" = { };
  };
}
