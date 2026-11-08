# The frozen grep UTF-8 test originally used the standalone public glibc.
# Preserve that complete construction graph when public MPFR moves to the owned
# recipe and Zstd moves to owned construction: substituting the base libc would change the historical test too.
{ tvpLib, recipes }:
let
  select =
    family: version: deps:
    let
      entry = family.versionTable.${version};
      packages = tvpLib.packages.mkVersions (
        family
        // {
          versionTable.${version} = entry // {
            def = entry.def // {
              deps = entry.def.deps // deps;
            };
          };
        }
      );
    in
    packages.${tvpLib.versions.attrName family.pname version};
  m4 = select recipes.m4.constructionRecipe "1.4.21" { };
  which = select recipes.which.constructionRecipe "2.21" { };
  bison = select recipes.bison.constructionRecipe "3.8.2" { inherit m4; };
  gmp = select recipes.gmp.constructionRecipe "6.3.0" { inherit m4; };
  isl = select recipes.isl "0.28" { inherit gmp; };
  mpfr = select recipes.mpfr.constructionRecipe "4.2.2" { inherit gmp; };
  mpc = select recipes.mpc.constructionRecipe "1.4.1" { inherit gmp mpfr; };
  zlib = select recipes.zlib.constructionRecipe "1.3.2" { };
  xz = select recipes.xz.constructionRecipe "5.8.4" { };
  libxcrypt = select recipes.libxcrypt.constructionRecipe "4.5.2" { };
  zstd = select recipes.zstd.constructionRecipe "1.5.7" { inherit xz zlib; };
  binutils = select recipes.binutils "2.42" { inherit bison zstd zlib; };
  gcc = select recipes.gcc "16.2.0" {
    inherit
      gmp
      isl
      which
      mpfr
      mpc
      zstd
      zlib
      libxcrypt
      binutils
      ;
  };
in
select recipes.glibc "2.39" { inherit gcc binutils bison; }
