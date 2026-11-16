# Earlier construction callers use the same family and an explicit owned context.
{ pkgs, tvp }:
let
  earlier = tvp.bases.gcc_16.reduced;
  check =
    directory: family: version:
    let
      index = import directory { inherit pkgs tvp; };
      recipe = index.recipes.${family};
      package = index.instantiate {
        inherit version;
        base = earlier;
      };
      factory = recipe.extraArgs.mkTests.override {
        tests =
          {
            package,
            lib,
            context,
          }:
          {
            selected = {
              inheritedVersion = package.version;
              inheritedBase = package.specification.base.name;
              ownedContext = context ? mkTest;
            };
          };
      };
      selected = (factory package).selected;
    in
    selected.inheritedVersion == version
    && selected.inheritedBase == earlier.name
    && selected.ownedContext
    && package ? testContext;
  contracts = {
    python-minimal = check ../../../runtimes/python-minimal "python-minimal" "3.12.5";
    python-build = check ../../../runtimes/python-build "python-build" "3.12.5";
    expat = check ../. "expat" "2.9.0";
    isl = check ../../isl "isl" "0.28";
    linux-headers = check ../../linux-headers "linux-headers" "6.9";
  };
in
assert builtins.all (result: result) (builtins.attrValues contracts);
{
  inherit contracts;
  expected = "construction-callers";
}
