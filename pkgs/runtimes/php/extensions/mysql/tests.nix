{ pkgs, tvp }:
{
  package,
  lib,
  context,
}:
let
  module = package.extensionName;
  catalogue = import ../default.nix { inherit pkgs tvp; };
  runtime = import ../../with-extensions.nix {
    inherit lib tvp;
    php = package.php;
    extensions = catalogue.runtimeModules package.php package;
    settings.memory_limit = "128M";
  };
  php = "${runtime}/bin/php";
  mariadb = package.tvp.declaredTestDependencies.mariadb;
  inherit (package.specification.base) shell tools;
  registration = {
    mysqlnd = ''echo phpversion("mysqlnd");'';
    mysqli = ''
      if (mysqli_get_client_info() !== "mysqlnd " . PHP_VERSION) {
        throw new RuntimeException("mysqli is not using this PHP release of mysqlnd");
      }
      echo phpversion("mysqli");
    '';
    pdo_mysql = ''
      if (!in_array("mysql", PDO::getAvailableDrivers(), true)) {
        throw new RuntimeException("PDO MySQL driver missing");
      }
      echo phpversion("pdo_mysql");
    '';
  };
in
context.mkSuite {
  inherit package;
  tools = [ runtime ];
  tests = {
    load = {
      script = "${php} -r ${lib.escapeShellArg registration.${module}}";
      expected = if module == "mysqlnd" then "mysqlnd ${package.version}" else package.version;
    };
    roundtrip =
      if module == "mysqlnd" then
        {
          script = ''
            ${php} -r '
              ob_start();
              (new ReflectionExtension("mysqlnd"))->info();
              $info = ob_get_clean();
              foreach (["Compression", "extended SSL"] as $feature) {
                if (!str_contains($info, "$feature => supported")) {
                  throw new RuntimeException("mysqlnd did not register $feature support");
                }
              }
              if (!str_contains($info, "auth_plugin_caching_sha2_password")) {
                throw new RuntimeException("mysqlnd did not register caching_sha2_password");
              }
              echo "mysqlnd-features-ready";
            '
          '';
          expected = "mysqlnd-features-ready";
        }
      else
        {
          tools = [
            runtime
            mariadb
            tools.sed
            tools.gawk
          ];
          script = ''
            ${shell}/bin/bash ${./with-mariadb.sh} ${mariadb} ${php} ${./query.php} ${lib.escapeShellArg module}
          '';
          expected = "mysql-smoke-roundtrip";
        };
  };
}
