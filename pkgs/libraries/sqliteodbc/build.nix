{
  tvp,
  lib,
  base,
  src,
  version,
  sqlite,
  unixodbc,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  # The release archive begins with ./sqliteodbc-VERSION/ rather than a bare
  # top-level directory. The shared unpacker removes the initial dot component.
  cwd = "source/sqliteodbc-${final.version}";
  command = steps.command {
    inherit cwd;
    environment = final.environment;
  };
  driver = "lib/libsqlite3odbc.so";
in
{
  pname = "sqliteodbc";
  inherit
    base
    src
    version
    sqlite
    unixodbc
    ;
  inherit (tools) bash coreutils;
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.pkg-config
    ];
    libraries = [
      final.sqlite
      final.unixodbc
    ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      inherit cwd;
      name = "sqliteodbc.prepare";
    })
    (command "sqliteodbc.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      # The release's Autoconf probes use the pre-C23 C dialect.
      export CFLAGS="''${CFLAGS:--g -O2} -std=gnu17"
      ./configure --prefix="$out" --enable-shared --disable-static \
        --without-sqlite --without-sqlite4 --without-dls \
        --with-sqlite3=${final.sqlite} --with-odbc=${final.unixodbc}
    '')
    (command "sqliteodbc.build" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash libsqlite3odbc.la
    '')
    (command "sqliteodbc.install" ''
      install -Dm755 .libs/libsqlite3odbc.so "$out/${driver}"
      install -Dm644 README "$out/share/doc/sqliteodbc/README"
      install -Dm644 license.terms "$out/share/licenses/sqliteodbc/license.terms"
      mkdir -p "$out/share/sqliteodbc"
      printf '[SQLite3]\nDriver=%s/${driver}\n' "$out" > "$out/share/sqliteodbc/odbcinst.ini"
    '')
    (steps.split "sqliteodbc.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText { paths = [ "share/sqliteodbc/odbcinst.ini" ]; })
    (outputs.strip { paths = [ driver ]; })
    (outputs.rpaths {
      paths = [ driver ];
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths { paths = [ driver ]; })
  ];
  meta = {
    description = "SQLite 3 ODBC driver";
    homepage = "https://ch-werner.hier-im-netz.de/sqliteodbc/";
    license = lib.licenses.tcltk;
    platforms = [ "x86_64-linux" ];
  };
}
