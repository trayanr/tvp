# The frozen grep UTF-8 test originally used the standalone public glibc.
# Preserve that complete construction graph when public MPFR moves to the owned
# recipe: substituting the base libc would change the historical test too.
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
  gcc = select recipes.gcc "16.2.0" { inherit mpfr mpc; };
in
select recipes.glibc "2.39" { inherit gcc; }
