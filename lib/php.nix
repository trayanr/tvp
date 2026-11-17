# PHP extension families use the ordinary constructor and dependency registry.
{ lib }:
{
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
      # Resolve an implicit base from the effective PHP on every override.
      # Explicit `.override { base = ...; }` remains an ordinary argument.
      constructor =
        call:
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
      family = tvp.lib.packages.mkFamily {
        pname = "php-${name}";
        inherit source tests testDeps;
        versionTable = builtins.mapAttrs (
          _: entry:
          entry
          // {
            def = entry.def // {
              inherit constructor;
              deps = {
                php = tvp.packages.php;
                autoconf = tvp.packages.autoconf_2;
                automake = tvp.packages.automake_1;
                libtool = tvp.packages.libtool_2;
              } // entry.def.deps;
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
