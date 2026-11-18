# Evaluate compatibility and cache boundaries without compiling a PHP matrix.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  php = tvp.packages.php_8_5;
  redis = php.extensions.redis;
  igbinary = php.extensions.igbinary;
  dblib = php.extensions.pdo_dblib;
  dblibEngine = tvp.canonical.php_8_5_12;
  dblibOtherRelease = tvp.canonical.php_8_5_11;
  igbinaryEngines = lib.filterAttrs (
    name: engine:
    lib.hasPrefix "php_" name
    && builtins.compareVersions engine.version "7.0" >= 0
    && builtins.compareVersions engine.version "8.6" < 0
  ) tvp.canonical;
  igbinaryPairs = builtins.length (builtins.attrNames igbinaryEngines);
  dblibPairs = builtins.length (
    builtins.attrNames (lib.filterAttrs (name: _: lib.hasPrefix "php_8_5_" name) tvp.canonical)
  );
  mysqlModules = [
    "mysqlnd"
    "mysqli"
    "pdo_mysql"
  ];
  mysqlPairs = builtins.length mysqlModules * dblibPairs;
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
  custom = php.buildExtension {
    name = "tvp_hello";
    version = "1.0.0";
    src = ./fixtures/php-extension;
    meta.description = "Public PHP extension fixture";
  };
  compatibleCustom = custom.override {
    phpCompatibility = {
      min = "8.2";
      before = "8.6";
    };
  };
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
  runtimeSample = tvp.canonical.php_8_0_0;
  runtimeZlib = runtimeSample.specification.zlib;
  runtimeLzma = runtimeSample.specification.libxml2.specification.liblzma;
  replacementZlib = runtimeZlib.editSteps (
    xs:
    xs
    ++ [
      {
        name = "php.runtime-zlib-probe";
        run = "true";
      }
    ]
  );
  runtimeReplacement = runtimeSample.editRuntime (
    r:
    r
    // {
      libraries = map (p: if p.pname == runtimeZlib.pname then replacementZlib else p) r.libraries;
    }
  );
  rpathCommand =
    package: (builtins.head (builtins.filter (s: s.name == "output.rpaths") package.buildSteps)).run;
  runtimeCommand =
    package:
    (builtins.head (builtins.filter (s: s.name == "php-runtime.configure") package.buildSteps)).run;
  has =
    needle: haystack:
    lib.hasInfix (builtins.unsafeDiscardStringContext needle) (
      builtins.unsafeDiscardStringContext haystack
    );
  results = {
    php52AbsoluteModulePaths =
      let
        legacyPHP = tvp.packages.php_5_2;
        php53 = tvp.packages.php_5_3;
        withRedis = engine: engine.withExtensions { extensions = extensions: [ extensions.redis ]; };
        directory = ''extension_dir="/"'';
      in
      has directory (runtimeCommand (withRedis legacyPHP))
      && !(has directory (runtimeCommand (legacyPHP.withExtensions { })))
      && !(has directory (runtimeCommand (withRedis php53)))
      && !(has directory (runtimeCommand runtime));
    legacyRedisBuilderContract =
      builtins.functionArgs (import ../../pkgs/runtimes/php/extensions/redis/build-2.2.8.nix)
      == builtins.functionArgs (import ../../pkgs/runtimes/php/extensions/build-phpize.nix);
    runtimeLibraryDependencies = has runtimeLzma.outPath (rpathCommand runtimeSample);
    runtimeProviderPrecedence =
      let
        rpaths = rpathCommand runtimeReplacement;
      in
      runtimeReplacement.artifact.drvPath == runtimeSample.artifact.drvPath
      && has replacementZlib.outPath rpaths
      && !(has runtimeZlib.outPath rpaths);
    publicBuilder =
      custom.php.drvPath == php.drvPath
      && custom.modulePath == "lib/php/extensions/tvp_hello.so"
      && custom.meta.description == "Public PHP extension fixture"
      &&
        (php.out.buildExtension {
          name = "tvp_hello";
          version = "1.0.0";
          src = ./fixtures/php-extension;
          meta.description = "Public PHP extension fixture";
        }).drvPath == custom.drvPath;
    publicBuilderDefaultsToExactPHP = rejects (custom.override { php = otherPHP; });
    publicBuilderExplicitCompatibility =
      (compatibleCustom.override { php = otherPHP; }).php.drvPath == otherPHP.drvPath
      && builtins.isString (compatibleCustom.override { php = otherPHP; }).drvPath;
    publicBuilderFollowsEffectiveBase =
      (custom.edit (spec: spec // { php = alternate; })).specification.base.compiler.drvPath
      == alternate.specification.base.compiler.drvPath;
    publicBuilderComposes =
      (builtins.head
        (php.withExtensions {
          extensions = [ custom ];
        }).enabledExtensions
      ).drvPath == custom.drvPath;
    publicFamilyDefaultBuilder =
      let
        family = tvp.lib.php.mkExtensionFamily {
          inherit tvp;
          name = "tvp_hello";
          versionTable = tvp.lib.packages.mkTable [
            {
              def.opts = {
                phpCompatibility = {
                  min = "8.2";
                  before = "8.6";
                };
                sourceMode = "auto";
              };
              releases."1.0.0" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
            }
          ];
          source = _: ./fixtures/php-extension;
          tests = _: { };
        };
      in
      builtins.isString (family.instantiate { version = "1.0.0"; }).drvPath;
    selectedRelease =
      php.extensions.redis.version == "6.3.0"
      && tvp.packages.php_7_3.extensions.redis.version == "6.0.2"
      && tvp.packages.php_5_6.extensions.redis.version == "4.3.0";
    unsupportedEngine = rejects tvp.packages.php_5_1.extensions.redis;
    unsupportedExactRelease = rejects php.extensions.redis_2_2_8;
    igbinaryReleaseSelection =
      igbinary.version == "3.2.17RC1"
      && igbinary.php.drvPath == php.drvPath
      && tvp.packages.php_7_0.extensions.igbinary.version == "3.2.17RC1"
      && php.extensions.igbinary_3_2_17RC1.drvPath == igbinary.drvPath;
    igbinaryUnsupportedPHP = rejects tvp.packages.php_5_6.extensions.igbinary;
    dblibReleaseSelection =
      dblib.version == dblibEngine.version
      && dblib.php.drvPath == dblibEngine.drvPath
      && dblibOtherRelease.extensions.pdo_dblib.version == dblibOtherRelease.version
      && rejects dblibOtherRelease.extensions.pdo_dblib_8_5_12
      && rejects tvp.packages.php_8_4.extensions.pdo_dblib;
    dblibUsesEngineSource =
      let
        otherSource = dblibOtherRelease.specification.src;
        changedPHP = dblibEngine.override { src = otherSource; };
        rebound = changedPHP.extensions.pdo_dblib;
        unpack = package: (builtins.head package.buildSteps).run;
      in
      has dblibEngine.specification.src.outPath (unpack dblib)
      && has otherSource.outPath (unpack rebound)
      && !(has dblibEngine.specification.src.outPath (unpack rebound));
    dblibUsesEffectiveFreeTDS =
      let
        freetds = tvp.packages.freetds_1;
        alternateFreeTDS = freetds.editSteps (
          xs:
          xs
          ++ [
            {
              name = "freetds.dependency-probe";
              run = "true";
            }
          ]
        );
        changed = dblib.edit (spec: spec // { freetds = alternateFreeTDS; });
        configure =
          package:
          (lib.findFirst (
            step: step.name == "php-extension.configure"
          ) (throw "missing PDO_DBLIB configure step") package.buildSteps).run;
      in
      dblib.tvp.declaredDependencies.freetds.drvPath == freetds.drvPath
      && changed.tvp.declaredDependencies.freetds.drvPath == alternateFreeTDS.drvPath
      && has "--with-pdo-dblib=${alternateFreeTDS}" (configure changed)
      && !(has freetds.outPath (configure changed))
      && has alternateFreeTDS.outPath (rpathCommand changed);
    mysqlReleaseSelection = lib.all (
      module:
      let
        package = php.extensions.${module};
        overridden = package.override { php = dblibOtherRelease; };
      in
      package.version == php.version
      && package.php.drvPath == php.drvPath
      && has php.specification.src.outPath (builtins.head package.buildSteps).run
      && rejects overridden
    ) mysqlModules;
    mysqlRuntimeOrder =
      let
        names = runtime: map (module: module.extensionName) runtime.enabledExtensions;
      in
      names tvp.php.profiles.mysql == mysqlModules
      &&
        lib.all
          (
            module:
            names tvp.php.profiles.${module} == [
              "mysqlnd"
              module
            ]
          )
          [
            "mysqli"
            "pdo_mysql"
          ]
      &&
        names tvp.php.extensionMatrix.php_8_5_12--pdo_mysql_8_5_12.runtime == [
          "mysqlnd"
          "pdo_mysql"
        ];
    mysqlServerTestOnly = lib.all (
      module:
      let
        package = php.extensions.${module};
      in
      !(package.tvp.declaredDependencies ? mariadb)
      && (package.tvp.declaredTestDependencies ? mariadb) == (module != "mysqlnd")
    ) mysqlModules;
    coexistingExtensionFamilies =
      map (extension: extension.extensionName)
        (php.withExtensions {
          extensions = extensions: [
            extensions.redis
            extensions.igbinary
          ];
        }).enabledExtensions == [
        "redis"
        "igbinary"
      ];
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
      tvp.php.metadata.families.redis.declaredPairs == 296
      && tvp.php.metadata.families.igbinary.declaredPairs == igbinaryPairs
      && tvp.php.metadata.families.pdo_dblib.declaredPairs == dblibPairs
      && igbinaryPairs > 0
      && dblibPairs > 0
      && lib.all (name: tvp.php.metadata.families.${name}.declaredPairs == dblibPairs) mysqlModules
      && tvp.php.metadata.declaredPairs == 296 + igbinaryPairs + dblibPairs + mysqlPairs
      &&
        builtins.length (builtins.attrNames tvp.php.extensionTests)
        == 296 + igbinaryPairs + dblibPairs + mysqlPairs
      && tvp.php.metadata.namedTests == 2 * (296 + igbinaryPairs + dblibPairs + mysqlPairs)
      && tvp.php.extensionMatrix.php_8_5_12--redis_6_3_0.package.drvPath == redis.drvPath
      && tvp.php.extensionMatrix.php_8_5_12--igbinary_3_2_17RC1.package.drvPath == igbinary.drvPath
      && tvp.php.extensionMatrix.php_8_5_12--pdo_dblib_8_5_12.package.drvPath == dblib.drvPath
      && tvp.php.metadata.families.igbinary.extensionVersions == [ "3.2.17RC1" ]
      && tvp.php.metadata.upstreamIncluded == false;
    matrixInStandardCI =
      lib.all (
        name:
        tvp.smokeTests.metadata.subjects.${name} == [
          "load"
          "roundtrip"
        ]
        && tvp.testBatches.${name}.drvPath == tvp.php.extensionTests.${name}.drvPath
      ) (builtins.attrNames tvp.php.extensionMatrix)
      && tvp.smokeTests.metadata.namedTests == 608 + 2 * (igbinaryPairs + dblibPairs + mysqlPairs)
      && tvp.smokeTests.metadata.upstreamIncluded == false;
  };
in
assert
  lib.all (value: value) (builtins.attrValues results)
  || throw "PHP extension contracts failed: ${
    lib.concatStringsSep ", " (builtins.attrNames (lib.filterAttrs (_: passed: !passed) results))
  }";
results
