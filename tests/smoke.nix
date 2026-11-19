# Small installed-result checks. Full package and upstream suites stay separate.
{ pkgs, tvp }:
let
  opcacheEngine = tvp.packages.php_8_5;
  opcacheBuiltIn =
    import ../pkgs/runtimes/php/extensions/opcache/tests.nix
      {
        inherit tvp;
        builtIn = true;
      }
      {
        inherit (pkgs) lib;
        package = opcacheEngine;
        context = opcacheEngine.testContext;
      };
  subjects = {
    base-gcc_4_9_4 = {
      inherit (tvp.__legacyBases.gcc_4_9_4.tests) compile cxx;
    };
    base-gcc_9_5_0 = {
      inherit (tvp.__legacyBases.gcc_9_5_0.tests) compile cxx;
    };
    base-gcc_13_3_0 = {
      inherit (tvp.__legacyBases.gcc_13_3_0.tests) compile cxx;
    };
    base-gcc_16_2_0 = {
      inherit (tvp.__legacyBases.gcc_16_2_0.tests) compile cxx;
    };
    krb5_1_21_3 = {
      inherit (tvp.canonical.krb5_1_21_3.tests) gssapi sdk;
    };
    perl_5_30_3 = {
      inherit (tvp.canonical.perl_5_30_3.tests) version modules;
    };
    ruby_4_0_6 = {
      inherit (tvp.canonical.ruby_4_0_6.tests) version stdlib;
    };
    redis_8_10_3 = {
      inherit (tvp.canonical.redis_8_10_3.tests) version roundtrip;
    };
    keyutils_1_6_3 = {
      inherit (tvp.canonical.keyutils_1_6_3.tests) cli consumer;
    };
    freetds_1_5_21 = {
      inherit (tvp.canonical.freetds_1_5_21.tests) dblib tsql;
    };
    postgresql_16_16 = {
      inherit (tvp.canonical.postgresql_16_16.tests) client roundtrip;
    };
    tzdata_2026f = {
      inherit (tvp.canonical.tzdata_2026f.tests) layout transition;
    };
    "php_${builtins.replaceStrings [ "." ] [ "_" ] opcacheEngine.version}--opcache-builtin" =
      opcacheBuiltIn;
  } // builtins.mapAttrs (_: pair: pair.tests) tvp.php.extensionMatrix;
  batches = pkgs.lib.mapAttrs (
    name: suite:
    tvp.lib.tests.compatibility.mkBatch {
      inherit pkgs suite;
      name = "smoke-${name}";
    }
  ) subjects;
in
{
  inherit batches;
  metadata = {
    schema = "tvp.smoke-tests/v1";
    scope = "smoke";
    subjects = builtins.mapAttrs (_: suite: builtins.attrNames suite) subjects;
    namedTests = pkgs.lib.foldl' (count: suite: count + builtins.length (builtins.attrNames suite)) 0 (
      builtins.attrValues subjects
    );
    upstreamIncluded = false;
  };
  all = tvp.lib.tests.compatibility.mkAll {
    inherit pkgs batches;
    checks = { };
  };
}
