# PHP extension families use the ordinary constructor and dependency registry.
{ lib }:
let
  # Keep the argument names stable while resolving tools from the effective PHP.
  constructor =
    tvp: call:
    if !(call.args ? php) then
      tvp.builder call
    else
      tvp.builder (
        call
        // {
          args = builtins.removeAttrs call.args [ "base" ];
          argumentDefaults =
            inputs:
            call.argumentDefaults (
              inputs
              // {
                arguments = inputs.arguments // {
                  base = inputs.arguments.base or inputs.arguments.php.specification.base;
                };
              }
            )
            // {
              base = inputs.arguments.base or inputs.specification.php.specification.base;
            };
        }
      );
  buildTools = tvp: {
    autoconf = tvp.packages.autoconf_2;
    automake = tvp.packages.automake_1;
    libtool = tvp.packages.libtool_2;
  };
  phpize = ../pkgs/runtimes/php/extensions/build-phpize.nix;
in
{
  # One user-defined extension bound to one selected PHP SDK.
  buildExtension =
    {
      tvp,
      php,
      name,
      version,
      src,
      phpCompatibility ? null,
      configureOptions ? [ ],
      libraries ? [ ],
      loader ? "extension",
      compression ? "gzip",
      meta ? { },
      tests ? (_: { }),
      testDeps ? { },
    }:
    let
      engine = php.unwrapped or php;
    in
    constructor tvp {
      recipe = import phpize;
      args = buildTools tvp // {
        inherit
          tvp
          lib
          version
          src
          configureOptions
          libraries
          loader
          compression
          ;
        php = engine;
        extensionName = name;
        extensionMeta = meta;
        sourceMode = "auto";
        phpCompatibility =
          if phpCompatibility == null then { exact = engine.version; } else phpCompatibility;
      };
      argumentDefaults = _: { };
      dependencyNames = [
        "php"
        "autoconf"
        "automake"
        "libtool"
      ];
      metadata = {
        builder = "build-phpize.nix";
        definition = "custom-php-${name}";
        status.level = "ok";
        declaredTestDependencies = testDeps;
      };
      selection = {
        kind = "custom";
        category = "php-extension";
      };
      testContext =
        package:
        (import ./tests.nix { inherit lib; }).fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      mkTests =
        package:
        tests {
          inherit package lib;
          context = package.testContext;
        };
    };

  mkExtensionFamily =
    {
      tvp,
      name,
      versionTable,
      source,
      tests,
      testDeps ? { },
      meta ? { },
    }:
    let
      family = tvp.lib.packages.mkFamily {
        pname = "php-${name}";
        inherit source tests testDeps;
        versionTable = builtins.mapAttrs (
          _: entry:
          entry
          // {
            def = entry.def // {
              constructor = constructor tvp;
              builder = entry.def.builder or phpize;
              deps = {
                php = tvp.packages.php;
              } // buildTools tvp // entry.def.deps;
              opts = {
                extensionName = name;
                extensionMeta = meta;
              } // (entry.def.opts or { });
            };
          }
        ) versionTable;
      };
    in
    family
    // {
      instantiate =
        args:
        let
          package = family.instantiate args;
        in
        if args ? base then package.override { inherit (args) base; } else package;
    };
}
