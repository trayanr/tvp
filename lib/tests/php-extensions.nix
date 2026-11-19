# Evaluate compatibility and cache boundaries without compiling a PHP matrix.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  php = tvp.packages.php_8_5;
  redis = php.extensions.redis;
  igbinary = php.extensions.igbinary;
  apcu = php.extensions.apcu;
  dblib = php.extensions.pdo_dblib;
  dblibEngine = tvp.canonical.php_8_5_12;
  dblibOtherRelease = tvp.canonical.php_8_5_11;
  engines = lib.filterAttrs (name: _: lib.hasPrefix "php_" name) tvp.canonical;
  countEngines =
    range:
    builtins.length (
      builtins.filter (engine: tvp.lib.php.compatibility.matches range engine.version) (
        builtins.attrValues engines
      )
    );
  igbinaryPairs = countEngines {
    min = "7.0";
    before = "8.6";
  };
  php82Plus = countEngines { min = "8.2"; };
  php82To85 = countEngines {
    min = "8.2";
    before = "8.6";
  };
  opcachePairs = countEngines {
    min = "8.2";
    before = "8.5";
  };
  mongodbPairs =
    countEngines {
      min = "8.1";
      before = "8.6";
    }
    + php82To85;
  xdebugPairs =
    countEngines {
      min = "8.2";
      before = "8.4";
    }
    + php82To85;
  mongodb = tvp.canonical.php_8_2_35.extensions.mongodb_1;
  mysqlModules = [
    "mysqlnd"
    "mysqli"
    "pdo_mysql"
  ];
  imageAndSystemModules = [
    "gd"
    "gettext"
    "gmp"
    "sodium"
  ];
  bundledModules =
    mysqlModules
    ++ imageAndSystemModules
    ++ [
      "bcmath"
      "calendar"
      "curl"
      "exif"
      "ftp"
      "intl"
      "ldap"
      "mbstring"
      "pcntl"
      "pdo_dblib"
      "pdo_odbc"
      "pdo_pgsql"
      "pgsql"
      "soap"
      "sockets"
      "sysvsem"
      "zip"
    ];
  extensionPairs =
    296
    + 2 * igbinaryPairs
    + mongodbPairs
    + xdebugPairs
    + builtins.length bundledModules * php82Plus
    + php82To85
    + opcachePairs;
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
    hardLimitsAndGaps =
      let
        row =
          family: php: release:
          builtins.head (
            builtins.filter (
              r: r.php == php && r.release == release
            ) tvp.php.metadata.families.${family}.coverage.rows
          );
      in
      (row "redis" "7.4.33" "4.3.0").state == "gap"
      && (row "mongodb" "7.4.33" "1.21.13").state == "incompatible"
      && (row "mongodb" "8.2.35" "1.21.13").state == "packaged"
      && (row "bcmath" "8.1.34" "8.1.34").state == "gap"
      && (row "bcmath" "8.2.35" "8.2.35").state == "packaged"
      && (row "gd" "8.1.34" "8.1.34").state == "gap"
      &&
        (row "sodium" "7.1.33" "7.1.33").source == "https://www.php.net/manual/en/sodium.installation.php"
      && (row "sodium" "7.1.33" "7.1.33").state == "incompatible"
      && (row "sodium" "7.2.34" "7.2.34").state == "gap"
      && (row "pdo_odbc" "5.0.5" "5.0.5").state == "incompatible"
      && (row "pdo_odbc" "8.1.34" "8.1.34").state == "gap"
      && (row "imap" "8.1.34" "8.1.34").state == "gap"
      && (row "imap" "8.3.35" "8.3.35").kind == "bundled"
      && (row "imap" "8.4.27" "1.0.3").kind == "independent"
      && (row "imap" "8.5.12" "1.0.3").state == "packaged"
      && (row "opcache" "8.4.27" "8.4.27").state == "packaged"
      && (row "opcache" "8.5.12" "8.5.12").state == "builtin"
      &&
        lib.all
          (
            module:
            (row module "8.1.34" "8.1.34").state == "gap" && (row module "8.2.35" "8.2.35").state == "packaged"
          )
          [
            "exif"
            "ftp"
            "pcntl"
            "sockets"
            "sysvsem"
          ]
      && (row "mysqli" "8.1.34" "8.1.34").state == "gap"
      && (row "mysqli" "8.2.35" "8.2.35").state == "packaged"
      && (row "mysqlnd" "5.2.17" "5.2.17").state == "incompatible";
    hardLimitBoundaries =
      let
        matches = tvp.lib.php.compatibility.matches;
      in
      matches {
        min = "8.1";
        max = "8.99.99";
      } "8.1.0"
      && !(matches {
        min = "8.1";
        max = "8.99.99";
      } "9.0.0")
      && !(matches { before = "6.0"; } "6.0.0");
    hardLimitEvidenceAndConsistency =
      let
        report =
          requirements:
          tvp.lib.php.compatibility.report {
            phpVersions.php_8_0_30 = "8.0.30";
            versionTable."1.0".def = {
              opts.phpCompatibility = {
                min = "8.0";
                before = "8.6";
              };
              phpRequirements = requirements;
            };
          };
        rejectsReport =
          requirements: !(builtins.tryEval (builtins.deepSeq (report requirements) true)).success;
      in
      rejectsReport { min = "8.1"; }
      && rejectsReport {
        min = "8.1";
        reason = "The upstream API requires PHP 8.1";
        source = "https://example.invalid/package.xml";
      };
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
    mongodbCompatibility =
      mongodb.php.drvPath == tvp.canonical.php_8_2_35.drvPath
      && mongodb.version == "1.21.13"
      && tvp.canonical.php_8_2_35.extensions.mongodb.version == "2.5.7"
      && rejects (tvp.canonical.php_8_0_30.extensions.mongodb_1_21_13);
    extensionLibraryDeclarations = lib.all lib.id (
      lib.mapAttrsToList
        (
          extension: providers:
          let
            declared = php.extensions.${extension}.tvp.declaredDependencies;
          in
          lib.all (name: declared ? ${name}) providers
        )
        {
          curl = [ "curl" ];
          ftp = [ "openssl" ];
          gd = [
            "zlib"
            "libpng"
            "libjpeg-turbo"
            "libwebp"
            "freetype"
          ];
          gmp = [ "gmp" ];
          intl = [ "icu" ];
          ldap = [ "openldap" ];
          mbstring = [ "oniguruma" ];
          mongodb = [
            "openssl"
            "zlib"
          ];
          pdo_odbc = [ "unixodbc" ];
          pdo_pgsql = [
            "postgresql"
            "openssl"
            "krb5"
            "keyutils"
          ];
          pgsql = [
            "postgresql"
            "openssl"
            "krb5"
            "keyutils"
          ];
          soap = [ "libxml2" ];
          sodium = [ "libsodium" ];
          xdebug = [ "zlib" ];
          zip = [ "libzip" ];
        }
    );
    bundledReleaseSelection = lib.all (
      module:
      let
        package = php.extensions.${module};
      in
      package.version == php.version
      && package.php.drvPath == php.drvPath
      && has php.specification.src.outPath (builtins.head package.buildSteps).run
      && rejects (package.override { php = dblibOtherRelease; })
      && rejects (tvp.packages.php_8_1.extensions.${module})
    ) bundledModules;
    pgsqlReusesClientAndServer =
      let
        native = php.extensions.pgsql.tvp;
        pdo = php.extensions.pdo_pgsql.tvp;
      in
      native.declaredDependencies.postgresql.drvPath == pdo.declaredDependencies.postgresql.drvPath
      &&
        native.declaredTestDependencies.postgresql.drvPath
        == pdo.declaredTestDependencies.postgresql.drvPath;
    odbcDriverIsTestOnly =
      let
        odbc = php.extensions.pdo_odbc.tvp;
      in
      !(odbc.declaredDependencies ? sqliteodbc)
      && odbc.declaredTestDependencies.sqliteodbc.drvPath == tvp.packages.sqliteodbc.drvPath
      && odbc.declaredTestDependencies.unixodbc.drvPath == odbc.declaredDependencies.unixodbc.drvPath;
    soapUsesReleaseLibxml2 =
      lib.all
        (
          engine:
          engine.extensions.soap.tvp.declaredDependencies.libxml2.drvPath
          == engine.specification.libxml2.drvPath
        )
        [
          tvp.canonical.php_8_2_0
          php
        ];
    ftpTLS =
      let
        older = tvp.packages.php_8_3.extensions.ftp;
        newer = tvp.canonical.php_8_4_0.extensions.ftp;
        configure =
          package: (lib.findFirst (step: step.name == "php-extension.configure") null package.buildSteps).run;
      in
      has "--enable-ftp" (configure older)
      && has "--with-openssl-dir" (configure older)
      && !(has "--with-ftp-ssl" (configure older))
      && has "--enable-ftp" (configure newer)
      && has "--with-ftp-ssl" (configure newer)
      && !(has "--with-openssl-dir" (configure newer))
      &&
        newer.tvp.declaredDependencies.openssl.drvPath
        == newer.php.tvp.declaredDependencies.openssl.drvPath;
    ftpEffectiveOpenSSL =
      let
        ftp = php.extensions.ftp;
        original = tvp.packages.openssl;
        replacement = original.editSteps (
          steps:
          steps
          ++ [
            {
              name = "openssl.ftp-provider-probe";
              run = "true";
            }
          ]
        );
        overridden = ftp.override { openssl = replacement; };
        edited = ftp.edit (spec: spec // { openssl = replacement; });
        finalization = ftp.editSteps (
          map (step: if step.name == "output.rpaths" then step // { run = step.run + "\ntrue\n"; } else step)
        );
        runtimeOnly = ftp.editRuntime (spec: spec // { libraries = [ ]; });
      in
      ftp.tvp.declaredDependencies.openssl.drvPath == original.drvPath
      && overridden.tvp.declaredDependencies.openssl.drvPath == replacement.drvPath
      && overridden.tvp.declaredTestDependencies.opensslCli.drvPath == original.drvPath
      && !(overridden.tvp.declaredDependencies ? opensslCli)
      && has (lib.getLib replacement).outPath (rpathCommand overridden)
      && !(has (lib.getLib original).outPath (rpathCommand overridden))
      && overridden.artifact.drvPath != ftp.artifact.drvPath
      && edited.drvPath == overridden.drvPath
      && finalization.artifact.drvPath == ftp.artifact.drvPath
      && finalization.drvPath != ftp.drvPath
      && runtimeOnly.artifact.drvPath == ftp.artifact.drvPath
      && runtimeOnly.drvPath != ftp.drvPath;
    zipEffectiveLibrary =
      let
        zip = php.extensions.zip;
        original = tvp.packages.libzip;
        replacement = original.editSteps (
          steps:
          steps
          ++ [
            {
              name = "libzip.override-probe";
              run = "true";
            }
          ]
        );
        overridden = zip.override { libzip = replacement; };
        edited = zip.edit (spec: spec // { libzip = replacement; });
        runtimeOnly = zip.editRuntime (spec: spec // { libraries = [ ]; });
      in
      overridden.tvp.declaredDependencies.libzip.drvPath == replacement.drvPath
      && has replacement.outPath (rpathCommand overridden)
      && !(has original.outPath (rpathCommand overridden))
      && overridden.artifact.drvPath != zip.artifact.drvPath
      && edited.drvPath == overridden.drvPath
      && runtimeOnly.artifact.drvPath == zip.artifact.drvPath
      && runtimeOnly.drvPath != zip.drvPath;
    postgresEffectiveLibrary =
      let
        driver = php.extensions.pdo_pgsql;
        original = driver.specification.postgresql;
        replacement = original.overrideAttrs (_: {
          pname = "postgresql-extension-probe";
        });
        overridden = driver.override { postgresql = replacement; };
        configure =
          package: (lib.findFirst (step: step.name == "php-extension.configure") null package.buildSteps).run;
      in
      overridden.tvp.declaredDependencies.postgresql.drvPath == replacement.drvPath
      && overridden.tvp.declaredTestDependencies.postgresql.drvPath == original.drvPath
      && has "--with-pdo-pgsql=${replacement}" (configure overridden)
      && has replacement.lib.outPath (rpathCommand overridden);
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
    apcuReleaseSelection =
      apcu.version == "5.1.28"
      && apcu.php.drvPath == php.drvPath
      && php.extensions.apcu_5_1_28.drvPath == apcu.drvPath
      && tvp.packages.php_7_0.extensions.apcu.version == apcu.version
      && rejects tvp.packages.php_5_6.extensions.apcu;
    dblibReleaseSelection =
      dblib.version == dblibEngine.version
      && dblib.php.drvPath == dblibEngine.drvPath
      && dblibOtherRelease.extensions.pdo_dblib.version == dblibOtherRelease.version
      && rejects dblibOtherRelease.extensions.pdo_dblib_8_5_12
      && tvp.packages.php_8_2.extensions.pdo_dblib.version == tvp.packages.php_8_2.version
      && rejects tvp.packages.php_8_1.extensions.pdo_dblib;
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
    imageAndSystemReleaseSelection = lib.all (
      module:
      let
        package = php.extensions.${module};
      in
      package.version == php.version
      && package.php.drvPath == php.drvPath
      && has php.specification.src.outPath (builtins.head package.buildSteps).run
      && rejects (package.override { php = dblibOtherRelease; })
      && rejects tvp.packages.php_8_1.extensions.${module}
      && package.tvp.declaredTestDependencies == { }
    ) imageAndSystemModules;
    gmpEffectiveLibrary =
      let
        gmp = php.extensions.gmp;
        original = tvp.packages.gmp_6;
        replacement = tvp.packages.gmp_6_2_1;
        configured = gmp.override { gmp = replacement; };
        edited = gmp.edit (spec: spec // { gmp = replacement; });
        runtimeOnly = gmp.editRuntime (spec: spec // { libraries = [ replacement ]; });
        configure = lib.findFirst (
          step: step.name == "php-extension.configure"
        ) (throw "missing GMP configure step") configured.buildSteps;
      in
      configured.tvp.declaredDependencies.gmp.drvPath == replacement.drvPath
      && has "--with-gmp=${replacement}" configure.run
      && has replacement.outPath (rpathCommand configured)
      && !(has original.outPath (rpathCommand configured))
      && configured.artifact.drvPath != gmp.artifact.drvPath
      && edited.drvPath == configured.drvPath
      && runtimeOnly.artifact.drvPath == gmp.artifact.drvPath
      && runtimeOnly.drvPath != gmp.drvPath;
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
    imapReleaseSelection =
      let
        php83 = tvp.packages.php_8_3;
        bundled = php83.extensions.imap;
        pecl = php.extensions.imap;
        unpack = package: (builtins.head package.buildSteps).run;
      in
      bundled.version == php83.version
      && has php83.specification.src.outPath (unpack bundled)
      && pecl.version == "1.0.3"
      && pecl.php.drvPath == php.drvPath
      && pecl.tvp.source.url == "https://pecl.php.net/get/imap-1.0.3.tgz"
      && rejects php83.extensions.imap_1_0_3
      && rejects (bundled.override { php = php; });
    imapProviderEdits =
      let
        package = php.extensions.imap;
        original = tvp.packages.c-client;
        replacement = original.editSteps (
          steps:
          steps
          ++ [
            {
              name = "c-client.provider-probe";
              run = "true";
            }
          ]
        );
        overridden = package.override { c-client = replacement; };
        edited = package.edit (spec: spec // { c-client = replacement; });
        runtimeOnly = package.editRuntime (spec: spec // { libraries = [ ]; });
        configure =
          module: (lib.findFirst (step: step.name == "php-extension.configure") null module.buildSteps).run;
      in
      package.tvp.declaredDependencies.c-client.drvPath == original.drvPath
      && overridden.tvp.declaredDependencies.c-client.drvPath == replacement.drvPath
      && has "--with-imap=${replacement}" (configure overridden)
      && !(has original.outPath (configure overridden))
      && edited.drvPath == overridden.drvPath
      && runtimeOnly.artifact.drvPath == package.artifact.drvPath
      && runtimeOnly.drvPath != package.drvPath;
    opcacheLoadBoundary =
      let
        php84 = tvp.canonical.php_8_4_27;
        module = php84.extensions.opcache;
        shared = php84.withExtensions { extensions = [ module ]; };
        builtinRuntime = tvp.php.profiles.opcache;
      in
      module.version == php84.version
      && module.loader == "zend_extension"
      && has "zend_extension=" (runtimeCommand shared)
      && builtinRuntime.enabledExtensions == [ ]
      && rejects php.extensions.opcache
      && rejects (module.override { php = php; })
      && !(builtins.elem "php_8_5_12" tvp.php.metadata.families.opcache.unsupportedPHP);
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
      && tvp.php.metadata.families.apcu.declaredPairs == igbinaryPairs
      && tvp.php.metadata.families.mongodb.declaredPairs == mongodbPairs
      && tvp.php.metadata.families.xdebug.declaredPairs == xdebugPairs
      && tvp.php.metadata.families.imap.declaredPairs == php82To85
      && tvp.php.metadata.families.opcache.declaredPairs == opcachePairs
      && igbinaryPairs > 0
      && php82Plus > 0
      && lib.all (name: tvp.php.metadata.families.${name}.declaredPairs == php82Plus) bundledModules
      && tvp.php.metadata.declaredPairs == extensionPairs
      && builtins.length (builtins.attrNames tvp.php.extensionTests) == extensionPairs
      && tvp.php.metadata.namedTests == 2 * extensionPairs
      && tvp.php.extensionMatrix.php_8_5_12--redis_6_3_0.package.drvPath == redis.drvPath
      && tvp.php.extensionMatrix.php_8_5_12--igbinary_3_2_17RC1.package.drvPath == igbinary.drvPath
      && tvp.php.extensionMatrix.php_8_5_12--apcu_5_1_28.package.drvPath == apcu.drvPath
      && tvp.php.extensionMatrix.php_8_2_35--mongodb_1_21_13.package.drvPath == mongodb.drvPath
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
      &&
        tvp.smokeTests.metadata.subjects.php_8_5_12--opcache-builtin == [
          "load"
          "roundtrip"
        ]
      && tvp.smokeTests.metadata.namedTests == 18 + 2 * extensionPairs
      && tvp.smokeTests.metadata.upstreamIncluded == false;
  };
in
assert
  lib.all (value: value) (builtins.attrValues results)
  || throw "PHP extension contracts failed: ${
    lib.concatStringsSep ", " (builtins.attrNames (lib.filterAttrs (_: passed: !passed) results))
  }";
results
