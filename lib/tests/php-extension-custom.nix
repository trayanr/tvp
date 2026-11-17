# A real external-style extension: local source, public helper, installed PHP.
{ tvp }:
let
  php = tvp.packages.php_8_5;
  custom = php.buildExtension {
    name = "tvp_hello";
    version = "1.0.0";
    src = ./fixtures/php-extension;
    tests =
      { package, context, ... }:
      context.mkSuite {
        inherit package;
        tests.hello = {
          script = ''${package.php}/bin/php -n -dextension=${package}/${package.modulePath} -r 'echo tvp_hello();' '';
          expected = "custom-extension-ok";
        };
      };
  };
in
custom.tests.hello
