# Shared factory customization applies to current packages and supplied context.
{ pkgs, tvp }:
let
  factoryProbe =
    directory: family: attr:
    let
      index = import directory { inherit pkgs tvp; };
      package = index.canonical.${attr};
      factory = index.recipes.${family}.extraArgs.mkTests;
      selected =
        (factory.override {
          marker = "selected";
          tests =
            {
              package,
              lib,
              context,
            }:
            {
              configuration = package.testConfiguration.marker == "selected";
              effective = package.outPath == index.canonical.${attr}.outPath;
              context =
                (context.mkTest {
                  inherit package;
                  name = "factory-context";
                  script = "printf selected";
                  expected = "selected";
                }).tvp.base == package.tvp.base;
            };
        })
          package;
    in
    builtins.all (value: value) (builtins.attrValues selected);
in
{
  libyaml = factoryProbe ../../../libraries/libyaml "libyaml" "libyaml_0_2_4";
  ruby = factoryProbe ../. "ruby" "ruby_3_3_12";
  bundler = factoryProbe ../../../build-tools/bundler "bundler" "bundler_2_5_11";
}
