# Declared PHP/module pairs. Evaluation exposes jobs; it does not qualify them.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  extensions = import ./extensions { inherit pkgs tvp; };
  engines = lib.filterAttrs (name: _: lib.hasPrefix "php_" name) tvp.canonical;
  compatibleReleases =
    php: lib.filterAttrs (_: release: extensions.compatible php release) extensions.redisVersions;
  extensionMatrix = builtins.listToAttrs (
    lib.concatMap (
      phpName:
      let
        php = engines.${phpName};
      in
      map (
        extensionVersion:
        let
          extensionName = tvp.lib.versions.attrName "redis" extensionVersion;
          package = php.extensions.${extensionName};
        in
        lib.nameValuePair "${phpName}--${extensionName}" {
          phpVersion = php.version;
          inherit extensionVersion package;
          runtime = php.withExtensions {
            extensions = [ package ];
            settings.memory_limit = "128M";
          };
          tests = {
            inherit (package.tests) load roundtrip;
          };
        }
      ) (builtins.attrNames (compatibleReleases php))
    ) (builtins.attrNames engines)
  );
in
{
  profiles.redis = tvp.packages.php.withExtensions {
    extensions = extensions: [ extensions.redis ];
  };
  inherit extensionMatrix;
  # Independent build and small test handles for an explicit compatibility run.
  extensionPackages = builtins.mapAttrs (_: pair: pair.package) extensionMatrix;
  extensionTests = lib.mapAttrs (
    name: pair:
    pair.package.testContext.mkBatch {
      name = "php-extension-${name}";
      suite = pair.tests;
    }
  ) extensionMatrix;
  metadata = {
    schema = "tvp.php-extensions/v1";
    declaredPairs = builtins.length (builtins.attrNames extensionMatrix);
    phpVersions = builtins.length (builtins.attrNames engines);
    # Initially PHP 5.0 and 5.1 have no declared compatible Redis release.
    unsupportedPHP = builtins.attrNames (
      lib.filterAttrs (_: php: compatibleReleases php == { }) engines
    );
    scope = "declared compatibility; qualification requires individual execution evidence";
    testsPerPair = [
      "load"
      "roundtrip"
    ];
    upstreamIncluded = false;
  };
}
