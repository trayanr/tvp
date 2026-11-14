# Historical caller-selected pkgs observation; ordinary suites have a context API.
{ pkgs, tvp }:
let
  legacyFactory =
    directory: family: attr:
    let
      factory = (import directory { inherit pkgs tvp; }).recipes.${family};
      old = (tvp.lib.packages.mkVersions factory.constructionRecipe).${attr};
      chosen = pkgs // {
        runCommand = name: args: script: { selectedPkgs = true; };
      };
      # Historical observer uses the explicit retained factory; ordinary callers
      # customize the shared { package, lib, context } suite through `tests`.
      selected = factory.constructionRecipe;
      public = (selected.extraArgs.mkTests.override { pkgs = chosen; }) old;
      retained = (factory.constructionRecipe.extraArgs.mkTests.override { pkgs = chosen; }) old;
    in
    public.version.selectedPkgs && retained.version.selectedPkgs;
in
{
  libyaml = legacyFactory ../../../libraries/libyaml "libyaml" "libyaml_0_2_4";
  ruby = legacyFactory ../. "ruby" "ruby_3_3_12";
  bundler = legacyFactory ../../../build-tools/bundler "bundler" "bundler_2_5_11";
}
