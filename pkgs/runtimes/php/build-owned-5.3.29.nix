# PHP 5.3 through 7.0 use explicit library prefixes and require a crypt
# provider. The external SQLite prefixes prevent using the bundled copy.
# Complete ordinary procedure; exact retained root remains build-5.3.29.nix.
{
  tvp,
  lib,
  base,
  src,
  version,
  openssl,
  zlib,
  libxml2,
  readline,
  ncurses,
  sqlite,
  libxcrypt,
  cStandard ? null,
  iconvFromBase ? false,
  parallelBuild ? true,
  configureProbeFlags ? [ ],
  compileFlags ? [ ],
  testFeatures ? { },
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  command =
    name:
    steps.command {
      environment = final.environment;
    } "php.${name}";
  make = "${tools.gnumake}/bin/make -j${
    if final.parallelBuild then "\"$NIX_BUILD_CORES\"" else "1"
  } SHELL=${tools.bash}/bin/bash";
in
{
  pname = "php";
  inherit
    base
    src
    version
    openssl
    zlib
    libxml2
    readline
    ncurses
    sqlite
    testFeatures
    libxcrypt
    cStandard
    iconvFromBase
    parallelBuild
    configureProbeFlags
    compileFlags
    doCheck
    ;
  inherit (tools) bash coreutils;
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
      tools.gnumake
      tools.pkg-config
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
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
  productionFlags =
    final.compileFlags
    ++ lib.optional (final.cStandard != null) "-std=${final.cStandard}";
  runtime = {
    libraries = final.environment.libraries;
    shell = tools.bash;
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "php.prepare-autotools";
    })
    (steps.shebangs {
      name = "php.source-shells";
      paths = [
        "build"
        "scripts"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${tools.bash}/bin/bash";
    })
    {
      name = "php.iconv-prefix";
      cwd = "source";
      tools = [ tools.python ];
      enabled = final.iconvFromBase;
      run = ''
        ${tools.python}/bin/python3 - <<'REPAIR'
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
      # Probe-only diagnostics must not enter configure's recorded CFLAGS.
      # Each command has a fresh environment; construction flags resume at build.
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE ${lib.concatStringsSep " " final.configureProbeFlags}"
      export CONFIG_SHELL=${tools.bash}/bin/bash
      export PKG_CONFIG=${tools.pkg-config}/bin/pkg-config
      export PKG_CONFIG_PATH=${
        lib.escapeShellArg (
          lib.concatMapStringsSep ":" (p: "${lib.getDev p}/lib/pkgconfig") final.environment.libraries
        )
      }
      export CPPFLAGS="''${CPPFLAGS:-} -I${lib.getDev final.ncurses}/include/ncursesw"
      ${tools.bash}/bin/bash ./configure --prefix="$out" --with-openssl=${lib.getDev final.openssl} \
        --with-libxml-dir=${lib.getDev final.libxml2} \
        --with-zlib=${lib.getDev final.zlib} \
        --with-sqlite3=${lib.getDev final.sqlite} \
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
      # Concurrent CLI/Phar installs share output directories. Use mkdir -p's
      # atomic directory handling instead of the old shtool helper's check/create.
      ${make} ${lib.escapeShellArg "mkinstalldirs=${tools.coreutils}/bin/mkdir -p"} install
      chmod -R u+w "$out"
    '')
  ];
  validationProfile = "installed-only";
  plan = final.productionPlan ++ [
    (steps.split "php.finalize")
    (outputs.copyArtifacts { })
    {
      name = "php.relocate-prefix";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./relocate.py} "$out"'';
    }
    (outputs.shebangs {
      paths = [
        "bin"
        "lib"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (outputs.strip {
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.rpaths {
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.development {
      libraries = [ ];
    })
    (outputs.checkPaths {
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
