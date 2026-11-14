# A public factory must pass caller-selected test tools into its retained route.
{ pkgs, tvp }:
let
  selected = pkgs // {
    runCommand = name: args: script: { selectedPkgs = true; };
    runCommandWith = args: script: { selectedPkgs = true; };
  };
  check =
    directory: family: name: testName:
    let
      factory = (import directory { inherit pkgs tvp; }).recipes.${family};
      package = (tvp.lib.packages.mkVersions factory.constructionRecipe).${name};
      tests = (factory.extraArgs.mkTests.override { pkgs = selected; }) package;
    in
    tests.${testName}.selectedPkgs or false;
  contracts = {
    python-minimal =
      check ../../../runtimes/python-minimal "python-minimal" "python-minimal_3_12_5"
        "version";
    python-build = check ../../../runtimes/python-build "python-build" "python-build_3_12_5" "version";
    expat = check ../. "expat" "expat_2_9_0" "consumer";
    isl = check ../../isl "isl" "isl_0_28" "version";
    linux-headers = check ../../linux-headers "linux-headers" "linux-headers_6_9" "version";
  };
in
assert builtins.all (result: result) (builtins.attrValues contracts);
{
  inherit contracts;
  expected = "legacy-callers";
}
