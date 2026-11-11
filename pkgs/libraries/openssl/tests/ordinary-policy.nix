# Evaluation-only regression for effective policy edits; no producer is built.
{ package }:
let
  original = package.compiler.defaultHardeningFlags;
  flag = builtins.head original;
  disable = (package.specification.hardeningDisable or [ ]) ++ [ flag ];
  edited = package.edit (spec: spec // { hardeningDisable = disable; });
  overridden = package.override { hardeningDisable = disable; };
  expected = builtins.filter (name: name != flag) original;
  check = changed: {
    compilerPolicy = changed.compiler.defaultHardeningFlags == expected;
    linkerPolicy = changed.compiler.bintools.hardeningPolicy.selected == expected;
    artifactChanges = changed.artifact.drvPath != package.artifact.drvPath;
    finalChanges = changed.drvPath != package.drvPath;
  };
in
assert original != [ ] || throw "OpenSSL policy fixture needs an enabled protection";
{
  directEdit = check edited;
  argumentOverride = check overridden;
}
