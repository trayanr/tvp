# Construction never follows the public default it is building. These exact
# selections keep the GCC16 construction on v3; MPFR uses the shared owned recipe.
{
  pkgs,
  tvpLib,
  recipes,
  construction,
}:
let
  parent = construction.bases.gcc13-owned-v3;
  inputs = construction.variants.gcc16;
  # Audit parsers keep their complete historical Python codec graph too.
  frozenTests =
    recipe:
    recipe
    // {
      testDeps = recipe.testDeps // {
        python3 = construction.variants.gcc13.isl_0_20.tvp.declaredTestDependencies.python3;
      };
    };
  # Frozen component test factories keep the original public discovery tool,
  # rather than following the newly promoted ordinary frontend.
  frozenPkgConfig = construction.variants.gcc13.ncurses_6_6.tvp.declaredTestDependencies.pkg-config;
  frozenDiscovery =
    recipe:
    recipe
    // {
      testDeps = recipe.testDeps // {
        pkg-config = frozenPkgConfig;
      };
    };
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
  gcc = select (frozenTests recipes.gcc.constructionRecipe) {
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
  binutils = select recipes.binutils.constructionRecipe {
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
  gmp = select recipes.gmp.constructionRecipe {
    "6.3.0" = {
      deps = {
        m4 = inputs.m4_1_4_21;
      };
    };
  };
  mpfr.gcc16 = builtins.listToAttrs (
    map
      (
        version:
        let
          name = tvpLib.versions.attrName "mpfr" version;
          package =
            (recipes.mpfr.instantiate {
              inherit version;
              base = construction.ownedBases.gcc13-owned-v3;
              deps.gmp = inputs.gmp_6_3_0;
            }).edit
              (
                spec:
                spec
                // {
                  tvp = spec.tvp // {
                    canonical = false;
                    variant = "gcc16";
                  };
                }
              );
        in
        {
          inherit name;
          value = tvpLib.packages.tagSelection {
            namespace = "variants.gcc16";
            selector = name;
            kind = "variant";
            pname = "mpfr";
            inherit version;
            canonical = name;
          } package;
        }
      )
      [
        "4.2.1"
        "4.2.2"
      ]
  );

  mpc = select recipes.mpc.constructionRecipe {
    "1.3.1" = {
      deps = {
        gmp = inputs.gmp_6_3_0;
        mpfr = inputs.mpfr_4_2_1;
      };
    };
  };
  isl =
    select
      (frozenTests (
        recipes.isl.constructionRecipe
        // {
          testDeps = recipes.isl.constructionRecipe.testDeps // {
            # This is the identical old public helper computation, not a gcc13-profile tool.
            patchelf = construction.variants.gcc13.isl_0_20.tvp.declaredTestDependencies.patchelf;
          };
        }
      ))
      {
        "0.28" = {
          deps = {
            gmp = inputs.gmp_6_3_0;
          };
        };
      };
  zlib =
    select
      (
        recipes.zlib.constructionRecipe
        // {
          testDeps = recipes.zlib.constructionRecipe.testDeps // {
            pkg-config = frozenPkgConfig;
            gzip = construction.variants.gcc13.zlib_1_3_2.tvp.declaredTestDependencies.gzip;
          };
        }
      )
      {
        "1.3.2" = { };
      };
  zstd =
    select
      (
        recipes.zstd.constructionRecipe
        // {
          testDeps = recipes.zstd.constructionRecipe.testDeps // {
            gzip = construction.variants.gcc13.zlib_1_3_2.tvp.declaredTestDependencies.gzip;
          };
        }
      )
      {
        "1.5.6" = {
          deps = {
            xz = inputs.xz_5_8_3;
            zlib = inputs.zlib_1_3_2;
          };
        };
      };
  libxcrypt =
    select
      (
        recipes.libxcrypt.constructionRecipe
        // {
          testDeps = recipes.libxcrypt.constructionRecipe.testDeps // {
            pkg-config = frozenPkgConfig;
            inherit (construction.variants.gcc13.libxcrypt_4_4_36.tvp.declaredTestDependencies)
              baseline
              coreutils
              gnused
              ;
          };
        }
      )
      {
        "4.4.36" = {
          deps = {
            perl = inputs.perl_5_44_0;
          };
        };
      };
  perl = select recipes.perl.constructionRecipe {
    "5.44.0" = { };
  };
  texinfo = select recipes.texinfo.constructionRecipe {
    "7.1" = {
      deps = {
        perl = inputs.perl_5_44_0;
        ncurses = inputs.ncurses_6_6;
        localeTools = parent.stdenv.cc.libc.bin;
      };
    };
  };
  which = select recipes.which.constructionRecipe {
    "2.21" = { };
  };
  m4 = select recipes.m4.constructionRecipe {
    "1.4.21" = { };
  };
  pkg-config = select recipes.pkg-config.constructionRecipe {
    "0.29.2" = { };
  };
  bison = select recipes.bison.constructionRecipe {
    "3.8.2" = {
      deps = {
        m4 = inputs.m4_1_4_21;
        perl = inputs.perl_5_44_0;
      };
    };
  };
  ncurses = select (frozenDiscovery recipes.ncurses.constructionRecipe) {
    "6.6" = {
      deps = {
        pkg-config = inputs.pkg-config_0_29_2;
      };
    };
  };
  xz = select (frozenDiscovery recipes.xz.constructionRecipe) {
    "5.8.3" = { };
  };
}
