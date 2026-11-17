# Evaluate every PHP recipe without compiling the historical matrix.
{ lib, tvp }:
let
  packages = lib.filterAttrs (name: _: lib.hasPrefix "php_" name) tvp.canonical;
  command =
    name: package: (builtins.head (builtins.filter (step: step.name == name) package.buildSteps)).run;
  selected = tvp.packages.php_8_0;
  explicitSerial = selected.override { parallelBuild = false; };
  install = command "php.install" tvp.packages.php_5_4;
  results = {
    allVersionsUseNixBuildCores = lib.all (
      package: lib.hasInfix ''-j"$NIX_BUILD_CORES"'' (command "php.build" package)
    ) (builtins.attrValues packages);
    allVersionsUseNixInstallCores = lib.all (
      package: lib.hasInfix ''-j"$NIX_BUILD_CORES"'' (command "php.install" package)
    ) (builtins.attrValues packages);
    noImplicitSerialDefault = lib.all (package: package.specification.parallelBuild or true) (
      builtins.attrValues packages
    );
    explicitCallerOverrideRetained =
      !explicitSerial.specification.parallelBuild
      && lib.hasInfix "-j1 " (command "php.build" explicitSerial);
    concurrentInstallDirectories =
      lib.hasInfix "mkinstalldirs=" install
      && lib.hasInfix (builtins.unsafeDiscardStringContext "${tvp.packages.php_5_4.specification.base.tools.coreutils}/bin/mkdir -p") install
      && !(lib.hasInfix "-j1 " install);
  };
in
assert lib.all (result: result) (builtins.attrValues results);
results
