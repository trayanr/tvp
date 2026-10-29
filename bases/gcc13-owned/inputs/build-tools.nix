# Exact recipe selections used to construct the owned GCC 13 environment.
{
  pkgs,
  tvpLib,
  recipes,
  construction,
}:
tvpLib.packages.mergeVariants {
  gzip = tvpLib.packages.mkVariants (
    recipes.gzip
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."1.13" = {
          deps = {
            gnugrep = construction.variants.gcc13.gnugrep_3_11;
          };
        };
      };
    }
  );
  gawk = tvpLib.packages.mkVariants (
    recipes.gawk
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."5.2.2" = {
          deps = {
            gmp = construction.variants.gcc13.gmp_6_3_0;
            mpfr = construction.variants.gcc13.mpfr_4_2_1;
            ncurses = construction.variants.gcc13.ncurses_6_6;
            readline = construction.variants.gcc13.readline_8_3;
          };
        };
      };
    }
  );
  file = tvpLib.packages.mkVariants (
    recipes.file
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."5.45" = {
          deps = {
            bzip2 = construction.variants.gcc13.bzip2_1_0_8;
            xz = construction.variants.gcc13.xz_5_8_3;
            zlib = construction.variants.gcc13.zlib_1_3_2;
            zstd = construction.variants.gcc13.zstd_1_5_6;
          };
        };
      };
    }
  );
  gnutar = tvpLib.packages.mkVariants (
    recipes.gnutar
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."1.35" = {
          deps = {
            acl = construction.variants.gcc13.acl_2_3_2;
            attr = construction.variants.gcc13.attr_2_5_2;
          };
        };
      };
    }
  );
  which = tvpLib.packages.mkVariants (
    recipes.which
    // {
      inherit pkgs;
      profiles = {
        gcc13 = {
          base = construction.bases.gcc13;
          versions."2.21" = { };
        };
      };
    }
  );
  gnumake = tvpLib.packages.mkVariants (
    recipes.gnumake
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."4.4.1" = { };
      };
    }
  );
  patch = tvpLib.packages.mkVariants (
    recipes.patch
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."2.7.6" = { };
      };
    }
  );
  findutils = tvpLib.packages.mkVariants (
    recipes.findutils
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."4.10.0" = {
          deps = {
            coreutils = construction.variants.gcc13.coreutils_9_5;
          };
        };
      };
    }
  );
  binutils = tvpLib.packages.mkVariants (
    recipes.binutils
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."2.42" = {
          deps = {
            bison = construction.variants.gcc13.bison_3_8_2;
            perl = construction.variants.gcc13.perl_5_44_0;
            pkg-config = construction.variants.gcc13.pkg-config_0_29_2;
            texinfo = construction.variants.gcc13.texinfo_7_1;
            zlib = construction.variants.gcc13.zlib_1_3_2;
            zstd = construction.variants.gcc13.zstd_1_5_6;
          };
        };
      };
    }
  );
  gnugrep = tvpLib.packages.mkVariants (
    recipes.gnugrep
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."3.11" = {
          deps = {
            pcre2 = construction.variants.gcc13.pcre2_10_44;
          };
        };
      };
    }
  );
  texinfo = tvpLib.packages.mkVariants (
    recipes.texinfo
    // {
      inherit pkgs;
      profiles = {
        gcc13 = {
          base = construction.bases.gcc13;
          versions."7.1" = {
            deps = {
              perl = construction.variants.gcc13.perl_5_44_0;
              ncurses = construction.variants.gcc13.ncurses_6_6;
              # This makeinfo builds GCC, which builds TVP's first glibc.
              # Its locale program must therefore come from the seed libc.
              localeTools = construction.bases.gcc13.stdenv.cc.libc.bin;
            };
          };
        };
      };
    }
  );
  autoconf = tvpLib.packages.mkVariants (
    recipes.autoconf
    // {
      inherit pkgs;
      profiles = {
        gcc13 = {
          base = construction.bases.gcc13;
          versions."2.73" = {
            deps = {
              m4 = construction.variants.gcc13.m4_1_4_21;
              perl = construction.variants.gcc13.perl_5_44_0;
            };
          };
        };
      };
    }
  );
  patchelf = tvpLib.packages.mkVariants (
    (removeAttrs recipes.patchelf [ "constructionBuilder" ])
    // {
      inherit pkgs;
      versionTable = builtins.mapAttrs (
        _: entry:
        entry
        // {
          def = entry.def // {
            builder = recipes.patchelf.constructionBuilder;
          };
        }
      ) recipes.patchelf.versionTable;
      profiles.gcc13-owned = {
        base = construction.bases.gcc13-owned;
        versions."0.19.2" = { };
      };
    }
  );
  pkg-config = tvpLib.packages.mkVariants (
    recipes.pkg-config
    // {
      inherit pkgs;
      profiles = {
        gcc13 = {
          base = construction.bases.gcc13;
          versions."0.29.2" = { };
        };
      };
    }
  );
  gnused = tvpLib.packages.mkVariants (
    recipes.gnused
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."4.9" = {
          deps = {
            acl = construction.variants.gcc13.acl_2_3_2;
          };
        };
      };
    }
  );
  bison = tvpLib.packages.mkVariants (
    recipes.bison
    // {
      inherit pkgs;
      profiles = {
        gcc13 = {
          base = construction.bases.gcc13;
          versions."3.8.2" = {
            deps = {
              m4 = construction.variants.gcc13.m4_1_4_21;
              perl = construction.variants.gcc13.perl_5_44_0;
            };
          };
        };
      };
    }
  );
  diffutils = tvpLib.packages.mkVariants (
    recipes.diffutils
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."3.10" = {
          deps = {
            coreutils = construction.variants.gcc13.coreutils_9_5;
          };
        };
      };
    }
  );
  coreutils = tvpLib.packages.mkVariants (
    recipes.coreutils
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."9.5" = {
          deps = {
            acl = construction.variants.gcc13.acl_2_3_2;
            gmp = construction.variants.gcc13.gmp_6_3_0;
          };
        };
      };
    }
  );
  bzip2 = tvpLib.packages.mkVariants (
    recipes.bzip2
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = construction.bases.gcc13;
        versions."1.0.8" = { };
      };
    }
  );
  m4 = tvpLib.packages.mkVariants (
    recipes.m4
    // {
      inherit pkgs;
      profiles = {
        gcc13 = {
          base = construction.bases.gcc13;
          versions."1.4.21" = { };
        };
      };
    }
  );
}
