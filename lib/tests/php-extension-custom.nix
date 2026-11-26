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
          script = "${package.php}/bin/php -n -dextension=${package}/${package.modulePath} -r 'echo tvp_hello();' ";
          expected = "custom-extension-ok";
        };
      };
  };
  runtime = php.withExtensions { extensions = [ custom ]; };
  alternatePHP = php.override { base = tvp.bases.gcc_13.full; };
  alternateModule = custom.override { php = alternatePHP; };
  overridden = runtime.override {
    php = alternatePHP;
    extension-tvp_hello = alternateModule;
  };
  edited = runtime.edit (
    spec:
    spec
    // {
      php = alternatePHP;
      extension-tvp_hello = alternateModule;
    }
  );
  empty = php.withExtensions { };
  inventoryMatches =
    package: engine: module:
    package.tvpInventory.schema == 1
    && package.tvpInventory.packages.runtime.drvPath == engine.drvPath
    &&
      map (extension: extension.drvPath) package.tvpInventory.packages.extensions == [ module.drvPath ];
in
assert inventoryMatches runtime php custom;
assert inventoryMatches overridden alternatePHP alternateModule;
assert inventoryMatches edited alternatePHP alternateModule;
assert empty.tvpInventory.packages.runtime.drvPath == php.drvPath;
assert empty.tvpInventory.packages.extensions == [ ];
custom.tests.hello
