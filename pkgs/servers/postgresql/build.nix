# PostgreSQL 16 core, bundled contrib modules, and the installed libpq/PGXS SDK.
{
  tvp,
  lib,
  base,
  src,
  version,
  icu,
  keyutils,
  krb5,
  libxml2,
  openssl,
  readline,
  tzdata,
  zlib,
  zstd ? null,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  elfPaths = [
    "bin"
    "lib"
  ];
  developmentLibraries = [
    final.openssl
    final.krb5
    final.keyutils
  ];
  buildLibraries = [
    final.icu
    final.krb5
    final.keyutils
    final.libxml2
    final.openssl
    final.readline
    # Configure's Readline link probe also needs its selected terminal library.
    final.readline.tvp.deps.ncurses
    final.zlib
  ] ++ lib.optional (final.zstd != null) final.zstd;
in
{
  pname = "postgresql";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    icu
    keyutils
    krb5
    libxml2
    openssl
    readline
    tzdata
    zlib
    zstd
    ;
  inherit (tools) bash coreutils;
  environment = {
    tools = [
      tools.gnumake
      tools.gawk
      tools.grep
      tools.sed
      tools.diffutils
      tools.findutils
      tools.pkg-config
    ];
    libraries = buildLibraries;
  };
  runtime.libraries = buildLibraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "bzip2";
    })
    (steps.prepareAutotools { name = "postgresql.prepare"; })
    (command "postgresql.bind-shell" ''
      # The Unix pg_ctl path directly executes a shell; use the selected
      # libc's pathname, just like its existing system and popen calls.
      file=src/bin/pg_ctl/pg_ctl.c
      test "$(grep -Fxc '#include <fcntl.h>' "$file")" = 1
      test "$(grep -Fc 'execl("/bin/sh", "/bin/sh", "-c", cmd,' "$file")" = 1
      sed -i '/^#include <fcntl.h>$/a #include <paths.h>' "$file"
      sed -i 's|execl("/bin/sh", "/bin/sh",|execl(_PATH_BSHELL, _PATH_BSHELL,|' "$file"
    '')
    (command "postgresql.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      "$CONFIG_SHELL" ./configure --prefix="$out" --libdir="$out/lib" \
        CFLAGS="''${CFLAGS:--O2} -std=gnu17" \
        --with-ssl=openssl --with-gssapi --with-icu --with-libxml${lib.optionalString (final.zstd != null) " --with-zstd"} \
        --with-system-tzdata=${final.tzdata}/share/zoneinfo
    '')
    (command "postgresql.build" "${make} world-bin")
    (command "postgresql.install" ''
      ${make} install-world-bin
      install -Dm644 COPYRIGHT "$out/share/licenses/postgresql/COPYRIGHT"
    '')
    (steps.split "postgresql.finalize")
    (outputs.copyArtifacts { })
    {
      name = "postgresql.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../../libraries/jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    }
    (outputs.shebangs {
      paths = [ "lib/pgxs/config" ];
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (outputs.strip {
      paths = elfPaths;
      elfKinds = [ "runtime" ];
    })
    (outputs.rpaths {
      paths = elfPaths;
      elfKinds = [ "runtime" ];
      libraries = final.runtime.libraries;
    })
    (outputs.development { libraries = developmentLibraries; })
    (outputs.checkPaths {
      paths = elfPaths;
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = {
    tls = true;
    gssapi = true;
    icu = true;
    libxml2 = true;
    zstd = final.zstd != null;
    lz4 = false;
    pam = false;
    systemd = false;
    osspUuid = false;
  };
  meta = {
    description = "PostgreSQL database server, client tools, and development libraries";
    homepage = "https://www.postgresql.org/";
    license = lib.licenses.postgresql;
    platforms = [ "x86_64-linux" ];
    mainProgram = "postgres";
  };
}
