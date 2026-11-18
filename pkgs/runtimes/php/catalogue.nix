# Declared PHP/module pairs. Evaluation exposes jobs; it does not qualify them.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  extensions = import ./extensions { inherit pkgs tvp; };
  engines = lib.filterAttrs (name: _: lib.hasPrefix "php_" name) tvp.canonical;
  compatibleReleases =
    php: family:
    lib.filterAttrs (_: release: extensions.compatible php release) extensions.versionTables.${family};
  extensionMatrix = builtins.listToAttrs (
    lib.concatMap (
      phpName:
      let
        php = engines.${phpName};
      in
      lib.concatMap (
        family:
        map (
          extensionVersion:
          let
            extensionName = tvp.lib.versions.attrName family extensionVersion;
            package = php.extensions.${extensionName};
          in
          lib.nameValuePair "${phpName}--${extensionName}" {
            phpVersion = php.version;
            extensionFamily = family;
            inherit extensionVersion package;
            runtime = php.withExtensions {
              extensions = extensions.runtimeModules php package;
              settings.memory_limit = "128M";
            };
            tests = {
              inherit (package.tests) load roundtrip;
            };
          }
        ) (builtins.attrNames (compatibleReleases php family))
      ) (builtins.attrNames extensions.versionTables)
    ) (builtins.attrNames engines)
  );
  extensionTests = lib.mapAttrs (
    name: pair:
    pair.package.testContext.mkBatch {
      name = "php-extension-${name}";
      suite = pair.tests;
    }
  ) extensionMatrix;
in
{
  profiles =
    let
      php = tvp.packages.php;
    in
    builtins.mapAttrs (
      name: _:
      php.withExtensions {
        extensions = extensions.runtimeModules php php.extensions.${name};
      }
    ) extensions.versionTables
    // {
      mysql = php.withExtensions {
        extensions = available: [
          available.mysqlnd
          available.mysqli
          available.pdo_mysql
        ];
      };
    };
  inherit extensionMatrix;
  # Independent build and small test handles for an explicit compatibility run.
  extensionPackages = builtins.mapAttrs (_: pair: pair.package) extensionMatrix;
  inherit extensionTests;
  extensionTestsAll = tvp.lib.tests.compatibility.mkAll {
    inherit pkgs;
    batches = extensionTests;
    checks = { };
  };
  metadata = {
    schema = "tvp.php-extensions/v1";
    declaredPairs = builtins.length (builtins.attrNames extensionMatrix);
    namedTests = lib.foldl' (count: pair: count + builtins.length (builtins.attrNames pair.tests)) 0 (
      builtins.attrValues extensionMatrix
    );
    phpVersions = builtins.length (builtins.attrNames engines);
    # Versions with no declared compatible release from any registered family.
    unsupportedPHP = builtins.attrNames (
      lib.filterAttrs (
        _: php:
        lib.all (family: compatibleReleases php family == { }) (builtins.attrNames extensions.versionTables)
      ) engines
    );
    families = builtins.mapAttrs (
      family: versionTable:
      let
        pairs = lib.filterAttrs (_: pair: pair.extensionFamily == family) extensionMatrix;
      in
      {
        declaredPairs = builtins.length (builtins.attrNames pairs);
        namedTests = lib.foldl' (count: pair: count + builtins.length (builtins.attrNames pair.tests)) 0 (
          builtins.attrValues pairs
        );
        extensionVersions = builtins.attrNames versionTable;
        unsupportedPHP = builtins.attrNames (
          lib.filterAttrs (_: php: compatibleReleases php family == { }) engines
        );
      }
    ) extensions.versionTables;
    scope = "declared compatibility; qualification requires individual execution evidence";
    testsPerPair = [
      "load"
      "roundtrip"
    ];
    upstreamIncluded = false;
  };
}
