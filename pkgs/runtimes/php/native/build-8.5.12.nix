# Native PHP 8.5.12: explicit source-GNU construction and current OpenSSL 4 API.
# Earlier PHP procedures and frozen construction remain independent.
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
  pkgConfig,
  openssl,
  zlib,
  libxml2,
  readline,
  ncurses,
  sqlite,
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
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
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
    pkgConfig
    openssl
    zlib
    libxml2
    readline
    ncurses
    sqlite
    testFeatures
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
        "sqlite"
      ]
  );
  environment = {
    tools = [
      final.gnumake
      final.pkgConfig
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
      final.sqlite
    ];
  };
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
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      export PKG_CONFIG=${final.pkgConfig}/bin/pkg-config
      export PKG_CONFIG_PATH=${
        lib.escapeShellArg (
          lib.concatMapStringsSep ":" (p: "${lib.getDev p}/lib/pkgconfig") final.environment.libraries
        )
      }
      export CPPFLAGS="''${CPPFLAGS:-} -I${lib.getDev final.ncurses}/include/ncursesw"
      ${final.bash}/bin/bash ./configure --prefix="$out" --with-openssl --with-zlib \
        --with-readline=${lib.getDev final.readline} --without-pear
    '')
    (command "build" make)
    (command "install" ''
      ${make} install
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
