# Independent PHP extensions use the selected interpreter's installed build SDK.
{
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
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  compatible =
    builtins.compareVersions final.php.version final.phpCompatibility.min >= 0
    && builtins.compareVersions final.php.version final.phpCompatibility.before < 0;
  modulePath = "lib/php/extensions/${final.extensionName}.so";
  command =
    name:
    steps.command {
      environment = final.environment;
    } "php-extension.${name}";
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  # Some historical PHP headers require the same dialect used by their tests.
  consumerStandard = final.php.tvp.features.consumerCStandard or null;
in
{
  pname = "php-${final.extensionName}";
  inherit
    base
    src
    version
    php
    extensionName
    phpCompatibility
    autoconf
    automake
    libtool
    configureOptions
    libraries
    loader
    extensionMeta
    ;
  inherit (tools) bash coreutils;
  environment = {
    tools = [
      final.php
      final.autoconf
      final.automake
      final.libtool
      tools.gnumake
      tools.pkg-config
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = final.libraries;
  };
  runtime.libraries = final.libraries;
  passthru = {
    inherit (final) php extensionName loader;
    inherit modulePath;
  };
  tvp.phpExtension = {
    name = final.extensionName;
    inherit (final) loader phpCompatibility;
    php = builtins.unsafeDiscardStringContext final.php.drvPath;
  };
  plan =

    assert
      compatible
      || throw "PHP extension ${final.extensionName} ${final.version} supports PHP ${final.phpCompatibility.min} through versions before ${final.phpCompatibility.before}; selected PHP is ${final.php.version}";
    assert
      builtins.match "[A-Za-z][A-Za-z0-9_]*" final.extensionName != null
      || throw "PHP extension: invalid module name";
    assert
      builtins.elem final.loader [
        "extension"
        "zend_extension"
      ]
      || throw "PHP extension: unsupported loader directive";
    steps.sequence [
      (steps.unpack {
        src = final.src;
        compression = "gzip";
      })
      (command "phpize" ''
        export PHP_AUTOCONF=${final.autoconf}/bin/autoconf
        export PHP_AUTOHEADER=${final.autoconf}/bin/autoheader
        ${final.php}/bin/phpize
        # phpize copies SDK files from the read-only PHP output.
        find build -type f -exec chmod u+w {} +
      '')
      (steps.prepareAutotools {
        name = "php-extension.prepare-autotools";
      })
      (command "configure" ''
        export CONFIG_SHELL=${tools.bash}/bin/bash
        export PKG_CONFIG=${tools.pkg-config}/bin/pkg-config
        ${lib.optionalString (
          consumerStandard != null
        ) ''export CFLAGS="''${CFLAGS:--g -O2} -std=${consumerStandard}"''}
        ${tools.bash}/bin/bash ./configure \
          --with-php-config=${final.php}/bin/php-config \
          ${lib.escapeShellArgs final.configureOptions}
      '')
      (command "build" make)
      # php-config's extension directory belongs to PHP's immutable output.
      # Install the built module directly into this independent package instead.
      (command "install" ''
        mkdir -p "$out/lib/php/extensions"
        ${tools.coreutils}/bin/install -m755 \
          ${lib.escapeShellArg "modules/${final.extensionName}.so"} \
          "$out/${modulePath}"
      '')
      (steps.split "php-extension.finalize")
      (outputs.copyArtifacts { })
      (outputs.strip {
        paths = [ modulePath ];
        elfKinds = [ "runtime" ];
      })
      (outputs.rpaths {
        paths = [ modulePath ];
        elfKinds = [ "runtime" ];
        libraries = final.runtime.libraries;
      })
      (outputs.checkPaths {
        paths = [ modulePath ];
        elfKinds = [ "runtime" ];
      })
    ];
  meta = {
    description = "PHP ${final.extensionName} extension";
    platforms = [ "x86_64-linux" ];
  } // final.extensionMeta;
}
