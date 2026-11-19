# MariaDB's core server and Connector/C. Replication plugins and optional
# storage engines with external dependencies need their own profiles.
{
  tvp,
  lib,
  base,
  src,
  version,
  bison,
  ncurses,
  openssl,
  pcre2,
  readline,
  unzip,
  zlib,
  fmtSource,
  fmtVersion,
  patches,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command {
    cwd = ".";
    environment = final.environment;
  };
  cmake = "${tools.cmake}/bin/cmake";
  fmtDirectory = "fmt/fmt-${final.fmtVersion}";
  cursesHeaders = "${lib.getDev final.ncurses}/include/ncursesw";
  elfPaths = [
    "bin"
    "lib"
  ];
  libraries = [
    final.ncurses
    final.openssl
    final.pcre2
    final.readline
    final.zlib
  ];
  scriptTools = [
    tools.coreutils
    tools.gawk
    tools.grep
    tools.sed
  ];
in
{
  pname = "mariadb";
  # MariaDB stores the installation prefix in compiled path constants.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    bison
    ncurses
    openssl
    pcre2
    readline
    unzip
    zlib
    fmtSource
    fmtVersion
    patches
    ;
  inherit (tools) bash coreutils;
  environment = {
    tools = [
      final.bison
      tools.cmake
      tools.gnumake
      tools.pkg-config
      tools.findutils
      tools.perl
    ]
    ++ scriptTools;
    inherit libraries;
    # Use the supported language mode on compilers that default to C23.
    overrides.values = {
      CFLAGS = "-O2 -std=gnu17 -I${cursesHeaders}";
      CXXFLAGS = "-I${cursesHeaders}";
    };
  };
  runtime = {
    inherit libraries;
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    {
      name = "mariadb.patches";
      cwd = "source";
      tools = [ tools.patch ];
      run = lib.concatMapStringsSep "\n" (
        patch: "patch --batch --fuzz=0 -p1 < ${lib.escapeShellArg "${patch}"}"
      ) final.patches;
    }
    {
      name = "mariadb.unpack-fmt";
      tools = [ final.unzip ];
      run = ''
        unzip -q ${final.fmtSource} -d fmt
        test -r "${fmtDirectory}/include/fmt/args.h"
      '';
    }
    (command "mariadb.configure" ''
      ${cmake} -S source -B build -G 'Unix Makefiles' \
        -DCMAKE_MAKE_PROGRAM=${tools.gnumake}/bin/make \
        -DCMAKE_INSTALL_PREFIX="$out" -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF \
        -DCMAKE_DISABLE_FIND_PACKAGE_LIBAIO=ON -DCMAKE_DISABLE_FIND_PACKAGE_URING=ON \
        -DINSTALL_LAYOUT=STANDALONE -DINSTALL_SCRIPTDIR=bin -DINSTALL_LIBDIR=lib \
        -DINSTALL_MYSQLTESTDIR=OFF -DINSTALL_SQLBENCHDIR=OFF \
        -DCURSES_NEED_WIDE=ON -DCURSES_INCLUDE_PATH=${cursesHeaders} \
        -DCURSES_NCURSES_LIBRARY=${lib.getLib final.ncurses}/lib/libncursesw.so \
        -DWITH_LIBFMT=system -DLIBFMT_INCLUDE_DIR="$PWD/${fmtDirectory}/include" \
        -DWITH_SSL=system -DWITH_PCRE=system -DWITH_ZLIB=system \
        -DWITH_SYSTEMD=no -DWITH_NUMA=OFF -DWITH_WSREP=OFF -DWITH_UNIT_TESTS=OFF \
        -DWITH_EMBEDDED_SERVER=OFF -DWITHOUT_ABI_CHECK=ON -DMYSQL_MAINTAINER_MODE=NO \
        -DPLUGIN_AUTH_PAM=NO -DPLUGIN_AUTH_PAM_V1=NO -DPLUGIN_AUTH_GSSAPI=NO \
        -DPLUGIN_COLUMNSTORE=NO -DPLUGIN_CONNECT=NO -DPLUGIN_MROONGA=NO -DPLUGIN_OQGRAPH=NO \
        -DPLUGIN_ROCKSDB=NO -DPLUGIN_S3=NO -DPLUGIN_SPIDER=NO
    '')
    (command "mariadb.build" ''${cmake} --build build --parallel "$NIX_BUILD_CORES"'')
    (command "mariadb.install" ''
      ${cmake} --install build
      install -Dm644 source/COPYING "$out/share/licenses/mariadb/COPYING"
      install -Dm644 source/libmariadb/COPYING.LIB "$out/share/licenses/mariadb/Connector-C-LGPL"
      install -Dm644 "${fmtDirectory}/LICENSE" "$out/share/licenses/mariadb/fmt-LICENSE"
      # The optional Perl front ends require additional runtime modules.
      rm -f "$out/bin/mytop" "$out/bin/mariadb-hotcopy" "$out/bin/mysqlhotcopy"
      for tool in mariadbd mariadb mariadb-admin mariadb-install-db; do
        test -x "$out/bin/$tool"
      done
    '')
    (steps.split "mariadb.finalize")
    (outputs.copyArtifacts { })
    {
      name = "mariadb.relocate";
      tools = [
        tools.python
        tools.patchelf
      ];
      run = ''${tools.python}/bin/python3 -B ${../../../lib/relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${tools.patchelf}/bin/patchelf'';
    }
    (outputs.shebangs {
      paths = [ "bin" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (
      outputs.shebangs {
        paths = [ "bin" ];
        names = [ "perl" ];
        interpreter = "${tools.perl}/bin/perl";
      }
      // {
        name = "mariadb.perl-shebangs";
      }
    )
    {
      name = "mariadb.install-db-tools";
      tools = [ tools.sed ];
      run = ''
        sed -i '2i export PATH=${lib.makeBinPath scriptTools}:"$PATH"' "$out/bin/mariadb-install-db"
      '';
    }
    (outputs.strip {
      paths = elfPaths;
      elfKinds = [ "runtime" ];
    })
    {
      name = "mariadb.self-rpaths";
      tools = [
        tools.binutils
        tools.patchelf
        tools.python
      ];
      run = ''${tools.python}/bin/python3 -B ${../../../lib/append-self-rpaths.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            paths = elfPaths;
            directories = [ "lib" ];
            readelf = "${tools.binutils}/bin/readelf";
            patchelf = "${tools.patchelf}/bin/patchelf";
          }
        )
      } ${../../../lib/native-output}'';
    }
    (outputs.rpaths {
      paths = elfPaths;
      elfKinds = [ "runtime" ];
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths {
      paths = elfPaths;
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = {
    tls = true;
    systemd = false;
    galera = false;
    nativeAio = false;
    rocksdb = false;
    columnstore = false;
  };
  meta = {
    description = "MariaDB database server and client tools";
    homepage = "https://mariadb.org/";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "mariadbd";
  };
}
