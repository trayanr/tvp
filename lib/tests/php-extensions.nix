# Evaluate compatibility and cache boundaries without compiling a PHP matrix.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  php = tvp.packages.php_8_5;
  redis = php.extensions.redis;
  otherPHP = tvp.packages.php_8_2;
  runtime = php.withExtensions {
    extensions = extensions: [ extensions.redis ];
    settings.memory_limit = "128M";
  };
  configured = runtime.override { settings.memory_limit = "256M"; };
  empty = php.withExtensions { };
  alternate = php.override { base = tvp.bases.gcc_13.full; };
  edited = redis.edit (spec: spec // { php = alternate; });
  overridden = redis.override { php = alternate; };
  explicitBase = (redis.override { base = tvp.bases.gcc_16.full; }).edit (
    spec: spec // { php = alternate; }
  );
  otherModule = redis.override { extensionName = "other"; };
  ordered = php.withExtensions {
    extensions = [
      otherModule
      redis
    ];
  };
  rejects = package: !(builtins.tryEval package.drvPath).success;
  results = {
    selectedRelease =
      php.extensions.redis.version == "6.3.0"
      && tvp.packages.php_7_3.extensions.redis.version == "6.0.2"
      && tvp.packages.php_5_6.extensions.redis.version == "4.3.0";
    unsupportedEngine = rejects tvp.packages.php_5_1.extensions.redis;
    unsupportedExactRelease = rejects php.extensions.redis_2_2_8;
    engineUnchanged = php.drvPath == php.unwrapped.drvPath && redis.php.drvPath == php.drvPath;
    serverIsTestDependency =
      !(redis.tvp.declaredDependencies ? redis)
      && redis.tvp.declaredTestDependencies.redis.drvPath == tvp.packages.redis.drvPath;
    runtimeConfigurationOnly =
      runtime.artifact.drvPath == configured.artifact.drvPath
      && runtime.artifact.drvPath == empty.artifact.drvPath
      && runtime.drvPath != configured.drvPath
      && runtime.drvPath != empty.drvPath
      && (builtins.head configured.enabledExtensions).drvPath == redis.drvPath;
    mismatchedEngineRejected = rejects (runtime.override { php = otherPHP; });
    mismatchedModuleRejected = rejects (
      runtime.override {
        extension-redis = otherPHP.extensions.redis;
      }
    );
    editedModuleRejected = rejects (
      runtime.edit (
        spec:
        spec
        // {
          extension-redis = otherPHP.extensions.redis;
        }
      )
    );
    reservedSettingsRejected = rejects (runtime.override { settings.extension = "redis.so"; });
    malformedSettingsRejected = rejects (runtime.override { settings.memory_limit = "128M\nother=1"; });
    duplicateModulesRejected = rejects (
      php.withExtensions {
        extensions = [
          redis
          redis
        ];
      }
    );
    effectiveDuplicateRejected = rejects (ordered.override { extension-other = redis; });
    callerLoadOrder =
      map (extension: extension.extensionName) ordered.enabledExtensions == [
        "other"
        "redis"
      ];
    effectiveBaseFollowsPHP =
      edited.specification.base.compiler.drvPath == alternate.specification.base.compiler.drvPath
      && edited.drvPath == overridden.drvPath
      && explicitBase.specification.base.compiler.drvPath == tvp.bases.gcc_16.full.compiler.drvPath;
    explicitMatrix =
      tvp.php.metadata.declaredPairs == 296
      && builtins.length (builtins.attrNames tvp.php.extensionTests) == 296
      && tvp.php.extensionMatrix.php_8_5_12--redis_6_3_0.package.drvPath == redis.drvPath
      && tvp.php.metadata.upstreamIncluded == false;
  };
in
assert lib.all (value: value) (builtins.attrValues results);
results
