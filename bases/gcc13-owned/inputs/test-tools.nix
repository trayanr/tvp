# Frozen suites used this complete ordinary-tool construction before the owned
# catalogue waves. Keep the historical default-base procedures and inputs exact.
{ tvpLib, recipes }:
let
  select =
    family: version: deps:
    let
      entry = family.versionTable.${version};
    in
    (tvpLib.packages.mkVersions (
      family
      // {
        versionTable = family.versionTable // {
          ${version} = entry // {
            def = entry.def // {
              deps = entry.def.deps // deps;
            };
          };
        };
      }
    )).${tvpLib.versions.attrName family.pname version};
  m4 = select recipes.m4.constructionRecipe "1.4.21" { };
  gmp = select recipes.gmp.constructionRecipe "6.3.0" { inherit m4; };
  attr = select recipes.attr.constructionRecipe "2.6.0" { };
  acl = select recipes.acl.constructionRecipe "2.4.0" { inherit attr; };
in
select recipes.coreutils "9.5" { inherit gmp acl; }
