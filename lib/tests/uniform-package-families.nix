# Evaluated family authoring admission, separate from runtime qualification.
{ familyEntrypoints }:
let
  rows = builtins.concatMap (
    entry:
    map (
      name:
      let
        recipe = entry.recipes.${name};
      in
      {
        family = name;
        entrypoint = "pkgs/${builtins.concatStringsSep "/" entry.namespaces}/default.nix";
        sharedFamily = (recipe.origin.origin or null) == "tvp.lib.packages.mkFamily";
        independent = !recipe.retainedConstructionRecipe;
        versions = builtins.all (origin: (origin.origin or null) == "tvp.lib.packages.mkFamily") (
          builtins.attrValues recipe.versionOrigins
        );
      }
    ) (builtins.attrNames entry.recipes)
  ) familyEntrypoints;
  failed = builtins.filter (row: !(row.sharedFamily && row.independent && row.versions)) rows;
in
assert rows != [ ] || throw "No registered package families";
assert failed == [ ] || throw "Nonuniform package families: ${builtins.toJSON failed}";
{
  schema = "tvp.uniform-package-families/v1";
  familyIndexes = builtins.length familyEntrypoints;
  recipes = builtins.length rows;
  inherit rows;
  scope = "Evaluated family origins and absence of captured old indexes; no runtime qualification.";
}
