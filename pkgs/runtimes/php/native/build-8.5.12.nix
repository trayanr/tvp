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
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "php";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [
      gnumake
      pkgConfig
      sed
      grep
      gawk
      diffutils
      findutils
    ];
    libraries = [
      openssl
      zlib
      libxml2
      readline
      ncurses
      sqlite
    ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "php.prepare-autotools";
      bash = final.bash;
      python = toolPython;
      base = final.base;
    })
    (steps.shebangs {
      name = "php.source-shells";
      python = toolPython;
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
      export PKG_CONFIG=${pkgConfig}/bin/pkg-config
      export PKG_CONFIG_PATH=${
        lib.escapeShellArg (
          lib.concatMapStringsSep ":" (p: "${lib.getDev p}/lib/pkgconfig") final.environment.libraries
        )
      }
      export CPPFLAGS="''${CPPFLAGS:-} -I${lib.getDev ncurses}/include/ncursesw"
      ${final.bash}/bin/bash ./configure --prefix="$out" --with-openssl --with-zlib \
        --with-readline=${lib.getDev readline} --without-pear
    '')
    (command "build" make)
    (command "install" ''
      ${make} install
      chmod -R u+w "$out"
      mkdir -p "$out/share/php/upstream-tests"
      cp run-tests.php "$out/share/php/"
      # Fixed meaningful PHPT subset; tests are executed with the installed CLI.
      for test in ext/standard/tests/strings/str_rot13_basic.phpt ext/standard/tests/strings/strrev.phpt \
        ext/standard/tests/array/array_sum.phpt ext/standard/tests/array/array_product_variation1.phpt; do
        test -f "$test"
        cp "$test" "$out/share/php/upstream-tests/"
      done
    '')
    (outputs.shebangs {
      python = toolPython;
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
      python = toolPython;
      inherit binutils;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.rpaths {
      python = toolPython;
      inherit binutils patchelf;
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
      python = toolPython;
      libraries = [ ];
    })
    (outputs.checkPaths {
      python = toolPython;
      inherit binutils patchelf;
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
  } // testFeatures;
  meta = {
    description = "General-purpose PHP interpreter";
    homepage = "https://www.php.net/";
    license = lib.licenses.php301;
    platforms = [ "x86_64-linux" ];
    mainProgram = "php";
  };
}
