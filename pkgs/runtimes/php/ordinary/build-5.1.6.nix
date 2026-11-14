# PHP 5.1 unconditionally probes lex during configure, even for release
# archives with shipped scanners. It needs an explicit Flex build input.
# Complete owned procedure; retained construction remains in ../build-5.1.6.nix.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  toolPython,
  gnumake,
  gnutar,
  gzip,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  binutils,
  patchelf,
  pkg-config,
  openssl,
  zlib,
  libxml2,
  readline,
  ncurses,
  sqlite,
  libxcrypt,
  flex,
  cStandard ? null,
  iconvFromBase ? false,
  parallelBuild ? false,
  testFeatures ? { },
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "php.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j${
    if final.parallelBuild then "\"$NIX_BUILD_CORES\"" else "1"
  } SHELL=${final.bash}/bin/bash'';
in
{
  pname = "php";
  inherit
    base
    src
    version
    bash
    coreutils
    toolPython
    gnumake
    gnutar
    gzip
    findutils
    sed
    grep
    gawk
    diffutils
    binutils
    patchelf
    pkg-config
    openssl
    zlib
    libxml2
    readline
    ncurses
    sqlite
    testFeatures
    libxcrypt
    flex
    cStandard
    iconvFromBase
    parallelBuild
    ;
  artifactName = "${final.pname}-${final.version}";
  dependencyProviders = builtins.listToAttrs (
    map
      (name: {
        inherit name;
        value =
          let
            matches = builtins.filter (p: p.pname == final.${name}.pname) final.runtime.libraries;
          in
          if builtins.length matches == 1 then
            builtins.head matches
          else
            throw "PHP: expected one runtime provider for ${name}";
      })
      [
        "openssl"
        "zlib"
        "libxml2"
        "readline"
        "ncurses"
        "libxcrypt"
        "sqlite"
      ]
  );
  environment = {
    tools = [
      final.gnumake
      final.flex
      final.pkg-config
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
    ];
    libraries = [
      final.openssl
      final.zlib
      final.libxml2
      final.readline
      final.ncurses
      final.libxcrypt
      final.sqlite
    ];
  };
  productionFlags = [
    "-fcommon"
  ] ++ lib.optional (final.cStandard != null) "-std=${final.cStandard}";
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      findutils = final.findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "php.prepare-autotools";
      bash = final.bash;
      python = final.toolPython;
      base = final.base;
    })
    (steps.shebangs {
      name = "php.source-shells";
      python = final.toolPython;
      paths = [
        "build"
        "scripts"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    {
      name = "php.iconv-prefix";
      cwd = "source";
      tools = [ final.toolPython ];
      enabled = final.iconvFromBase;
      run = ''
        ${final.toolPython}/bin/python3 - <<'REPAIR'
              from pathlib import Path
              p = Path("configure")
              text = p.read_text()
              old = 'PHP_ICONV_PREFIX="/usr"'
              assert old in text
              p.write_text(text.replace(old, 'PHP_ICONV_PREFIX="${lib.getDev final.base.compiler.libc}"'))
              REPAIR
      '';
    }
    (command "configure" ''
      export CFLAGS="-g -O2 ${lib.concatStringsSep " " final.productionFlags}"
      export CONFIG_SHELL=${final.bash}/bin/bash
      export PKG_CONFIG=${final.pkg-config}/bin/pkg-config
      export PKG_CONFIG_PATH=${
        lib.escapeShellArg (
          lib.concatMapStringsSep ":" (p: "${lib.getDev p}/lib/pkgconfig") final.environment.libraries
        )
      }
      export CPPFLAGS="''${CPPFLAGS:-} -I${lib.getDev final.ncurses}/include/ncursesw"
      ${final.bash}/bin/bash ./configure --prefix="$out" --with-openssl=${lib.getDev final.openssl} \
        --with-libxml-dir=${lib.getDev final.libxml2} \
        --with-zlib=${lib.getDev final.zlib} \
        --with-pdo-sqlite=${lib.getDev final.sqlite} \
        --with-readline=${lib.getDev final.readline} \
        --without-pear
    '')
    (command "build" ''
      export CFLAGS="-g -O2 ${lib.concatStringsSep " " final.productionFlags}"
      ${make}
    '')
    (command "install" ''
      mkdir -p "$out/bin"
      export CFLAGS="-g -O2 ${lib.concatStringsSep " " final.productionFlags}"
      ${make} install
      install -m755 sapi/cli/php "$out/bin/php"
      install -m755 sapi/cgi/php "$out/bin/php-cgi"
      test -x "$out/bin/phpize"
      test -x "$out/bin/php-config"
      chmod -R u+w "$out"
    '')
    (steps.split "php.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "php.relocate-prefix";
      tools = [ final.toolPython ];
      run = ''${final.toolPython}/bin/python3 -B ${../relocate.py} "$out"'';
    }
    (outputs.shebangs {
      python = final.toolPython;
      paths = [
        "bin"
        "lib"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (outputs.strip {
      python = final.toolPython;
      binutils = final.binutils;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.rpaths {
      python = final.toolPython;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.development {
      python = final.toolPython;
      libraries = [ ];
    })
    (outputs.checkPaths {
      python = final.toolPython;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = {
    passwordApi = true;
    shortArraySyntax = true;
    sqlite3Api = true;
    functionEntryEnd = true;
    digestApi = true;
    sqlite2Api = false;
  } // final.testFeatures;
  meta = {
    description = "General-purpose PHP interpreter";
    homepage = "https://www.php.net/";
    license = lib.licenses.php301;
    platforms = [ "x86_64-linux" ];
    mainProgram = "php";
  };
}
