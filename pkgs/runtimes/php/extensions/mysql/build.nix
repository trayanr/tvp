# Build the bundled modules independently against the selected PHP SDK.
args@{
  tvp,
  lib,
  base,
  src,
  version,
  php,
  extensionName,
  phpCompatibility,
  autoconf,
  automake,
  libtool,
  configureOptions ? [ ],
  libraries ? [ ],
  loader ? "extension",
  extensionMeta ? { },
  sourceMode ? "archive",
  compression ? "gzip",
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps tools;
  module = final.extensionName;
  providers = final.php.specification.dependencyProviders;
  options = {
    mysqlnd = [
      "--enable-mysqlnd"
      "--with-mysqlnd-ssl"
    ];
    mysqli = [
      "--with-mysqli=mysqlnd"
      "--without-mysql-sock"
    ];
    pdo_mysql = [
      "--with-pdo-mysql=mysqlnd"
      "--without-mysql-sock"
    ];
  };
  procedure = import ../build-phpize.nix args (
    final
    // {
      src = final.php.specification.src;
      configureOptions = options.${module} ++ final.configureOptions;
      libraries =
        lib.optionals (module == "mysqlnd") [
          providers.openssl
          providers.zlib
        ]
        ++ final.libraries;
    }
  );
  staged = steps.insertAfter "source.unpack" [
    {
      name = "php-mysql.select-source";
      tools = [ tools.python ];
      run = ''
        ${tools.python}/bin/python3 -B ${./select-source.py} "$TVP_SOURCE_ROOT" ${lib.escapeShellArg module}
      '';
    }
  ] procedure.plan;
in
procedure
// {
  plan =
    if module == "mysqlnd" then
      steps.insertAfter "php-mysql.select-source" [
        {
          name = "php-mysqlnd.include-config";
          cwd = "source";
          tools = [ tools.sed ];
          run = ''
            # The bundled sources normally get these defines from PHP's config.
            # For phpize, include the generated module config in each mysqlnd unit.
            test "$(sed -n '/^#define MYSQLND_H$/p' mysqlnd.h)" = '#define MYSQLND_H'
            sed -i '/^#define MYSQLND_H$/a\
            #ifdef HAVE_CONFIG_H\
            # include "config.h"\
            #endif' mysqlnd.h
          '';
        }
      ] staged
    else
      steps.replace "php-extension.configure" (
        step:
        step
        // {
          run = ''
            # mysqli and PDO use the matching mysqlnd headers from this source tree.
            export CPPFLAGS="-I$PWD ''${CPPFLAGS:-}"
          ''
          + step.run;
        }
      ) staged;
}
