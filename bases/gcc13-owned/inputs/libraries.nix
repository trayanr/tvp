# Exact recipe selections used to construct the owned GCC 13 environment.
{
  pkgs,
  tvpLib,
  recipes,
  construction,
}:
tvpLib.packages.mergeVariants {
  readline = tvpLib.packages.mkVariants (
    recipes.readline.constructionRecipe
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."8.3" = {
          deps = {
            ncurses = construction.variants.gcc13.ncurses_6_6;
          };
        };
      };
    }
  );
  linux-headers = tvpLib.packages.mkVariants (
    recipes.linux-headers.constructionRecipe
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."6.9" = {
          deps = {
            perl = construction.variants.gcc13.perl_5_44_0;
          };
        };
      };
    }
  );
  acl = tvpLib.packages.mkVariants (
    recipes.acl.constructionRecipe
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."2.3.2" = {
          deps = {
            attr = construction.variants.gcc13.attr_2_5_2;
          };
        };
      };
    }
  );
  mpc = tvpLib.packages.mkVariants (
    recipes.mpc
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."1.3.1" = {
          deps = {
            gmp = construction.variants.gcc13.gmp_6_3_0;
            mpfr = construction.variants.gcc13.mpfr_4_2_1;
          };
        };
      };
    }
  );
  libxcrypt = tvpLib.packages.mkVariants (
    recipes.libxcrypt.constructionRecipe
    // {
      testDeps = recipes.libxcrypt.constructionRecipe.testDeps // {
        coreutils = import ./test-tools.nix { inherit tvpLib recipes; };
      };
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."4.4.36" = {
          deps = {
            perl = construction.variants.gcc13.perl_5_44_0;
          };
        };
      };
    }
  );
  xz = tvpLib.packages.mkVariants (
    recipes.xz.constructionRecipe
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."5.8.3" = { };
      };
    }
  );
  pcre2 = tvpLib.packages.mkVariants (
    recipes.pcre2.constructionRecipe
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."10.44" = { };
      };
    }
  );
  gmp = tvpLib.packages.mkVariants (
    recipes.gmp.constructionRecipe
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."6.3.0" = {
          deps = {
            m4 = construction.variants.gcc13.m4_1_4_21;
          };
        };
      };
    }
  );
  ncurses = tvpLib.packages.mkVariants (
    recipes.ncurses.constructionRecipe
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."6.6" = {
          deps = {
            pkg-config = construction.variants.gcc13.pkg-config_0_29_2;
          };
        };
      };
    }
  );
  mpfr = tvpLib.packages.mkVariants (
    recipes.mpfr.constructionRecipe
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."4.2.1" = {
          deps = {
            gmp = construction.variants.gcc13.gmp_6_3_0;
          };
        };
      };
    }
  );
  attr = tvpLib.packages.mkVariants (
    recipes.attr.constructionRecipe
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."2.5.2" = { };
      };
    }
  );
  zstd = tvpLib.packages.mkVariants (
    recipes.zstd.constructionRecipe
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."1.5.6" = {
          deps = {
            xz = construction.variants.gcc13.xz_5_8_3;
            zlib = construction.variants.gcc13.zlib_1_3_2;
          };
        };
      };
    }
  );
  zlib = tvpLib.packages.mkVariants (
    recipes.zlib.constructionRecipe
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."1.3.2" = { };
      };
    }
  );
  isl = tvpLib.packages.mkVariants (
    recipes.isl.constructionRecipe
    // {
      # The coverage parser is a frozen test input, including its codec graph.
      testDeps = recipes.isl.constructionRecipe.testDeps // {
        python3 = recipes.isl.constructionRecipe.testDeps.python3.override {
          zstd = (tvpLib.packages.mkVersions recipes.zstd.constructionRecipe).zstd_1_5_7;
        };
      };
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."0.20" = {
          deps = {
            gmp = construction.variants.gcc13.gmp_6_3_0;
          };
        };
      };
    }
  );
  glibc = tvpLib.packages.mkVariants (
    recipes.glibc.constructionRecipe
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."2.39" = {
          deps = {
            binutils = construction.variants.gcc13.binutils_2_42;
            bison = construction.variants.gcc13.bison_3_8_2;
            gcc = construction.variants.gcc13.gcc_13_3_0;
            linuxHeaders = construction.variants.gcc13.linux-headers_6_9;
            perl = construction.variants.gcc13.perl_5_44_0;
            python3Minimal = construction.variants.gcc13.python-minimal_3_12_5;
          };
        };
      };
    }
  );
}
