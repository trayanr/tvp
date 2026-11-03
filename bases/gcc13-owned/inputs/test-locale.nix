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
  mpfr = select recipes.mpfr.constructionRecipe "4.2.2" { };
  mpc = select recipes.mpc "1.4.1" { inherit mpfr; };
  zstd = select recipes.zstd.constructionRecipe "1.5.7" { };
  binutils = select recipes.binutils "2.42" { inherit zstd; };
  gcc = select recipes.gcc "16.2.0" {
    inherit
      mpfr
      mpc
      zstd
      binutils
      ;
  };
in
select recipes.glibc "2.39" { inherit gcc binutils; }
