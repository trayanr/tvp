# PostgreSQL 10–13 use separate core and contrib Makefile targets.
{
  tvp,
  lib,
  base,
  src,
  version,
  gettext,
  icu,
  keyutils,
  krb5,
  libpam,
  libuuid,
  libxml2,
  libxslt,
  openldap,
  openssl,
  perl,
  python,
  readline,
  tcl,
  tzdata,
  zlib,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  needsXml2Config =
    lib.versionOlder final.version "10.13"
    || (lib.versionAtLeast final.version "11" && lib.versionOlder final.version "11.8")
    || (lib.versionAtLeast final.version "12" && lib.versionOlder final.version "12.3");
  needsIcuTrue =
    (lib.versionAtLeast final.version "11" && lib.versionOlder final.version "11.11")
    || (lib.versionAtLeast final.version "12" && lib.versionOlder final.version "12.6")
    || (lib.versionAtLeast final.version "13" && lib.versionOlder final.version "13.2");
  # The selected binutils can put wall-clock timestamps in archives and their indexes.
  make = ''
    ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash \
      AROPT=crsD RANLIB="$RANLIB -D"'';
  elfPaths = [
    "bin"
    "lib"
  ];
  developmentLibraries = [
    final.openssl
    final.krb5
    final.keyutils
    final.openldap
  ];
  buildLibraries = [
    final.icu
    final.krb5
    final.keyutils
    final.libpam
    final.libuuid
    final.libxml2
    final.libxslt
    final.openldap
    final.openssl
    final.python
    final.readline
    # Configure's Readline link probe also needs its selected terminal library.
    final.readline.tvp.deps.ncurses
    final.tcl
    final.zlib
  ];
in
{
  pname = "postgresql";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    gettext
    icu
    keyutils
    krb5
    libpam
    libuuid
    libxml2
    libxslt
    openldap
    openssl
    perl
    python
    readline
    tcl
    tzdata
    zlib
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
      final.gettext
      final.perl
      final.python
      final.tcl
    ]
    ++ lib.optional needsXml2Config final.libxml2;
    libraries = buildLibraries;
  };
  runtime = {
    libraries = buildLibraries;
    # PL/Perl's shared library lives in Perl's architecture-specific CORE directory.
    dlopenDirectories = [ "${final.perl}/lib/${final.perl.version}/x86_64-linux/CORE" ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "bzip2";
    })
    (steps.prepareAutotools { name = "postgresql.prepare"; })
    (lib.optional (lib.versionOlder final.version "10.2") (
      command "postgresql.rename-rewind-copy-file-range" ''
        # Backport PostgreSQL 10.2's rename to avoid the glibc declaration.
        file=src/bin/pg_rewind/copy_fetch.c
        test "$(grep -Fc 'copy_file_range(' "$file")" = 4
        sed -i 's/\<copy_file_range(/rewind_copy_file_range(/g' "$file"
      ''
    ))
    (lib.optional (lib.versionOlder final.version "11") (
      command "postgresql.preserve-c-bool" ''
        # ICU includes stdbool.h. Load it first and retain PostgreSQL 10's
        # char-sized bool consistently in headers and source files.
        file=src/include/c.h
        test "$(grep -Fxc '#ifndef bool' "$file")" = 1
        sed -i '/^#ifndef bool$/i #include <stdbool.h>\n#undef bool\n#undef true\n#undef false' "$file"
      ''
    ))
    (lib.optional needsIcuTrue (
      command "postgresql.icu-true" ''
        # Later minor releases use the language boolean with newer ICU.
        file=src/backend/commands/collationcmds.c
        test "$(grep -Fc 'uloc_toLanguageTag(localename, buf, sizeof(buf), TRUE, &status);' "$file")" = 1
        sed -i '/uloc_toLanguageTag(localename, buf, sizeof(buf), TRUE, \&status);/s/TRUE/true/' "$file"
      ''
    ))
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
      export PERL=${final.perl}/bin/perl PYTHON=${final.python}/bin/python3
      # OpenLDAP 2.5 merged the threaded libldap_r implementation into libldap.
      grep -Fq -- '-lldap_r' configure
      sed -i 's/-lldap_r\>/-lldap/g' configure
      "$CONFIG_SHELL" ./configure --prefix="$out" --libdir="$out/lib" \
        CFLAGS="''${CFLAGS:--O2} -std=gnu17" \
        --enable-nls --with-openssl --with-gssapi --with-icu --with-libxml --with-libxslt \
        --with-ldap --with-pam --with-uuid=e2fs --with-perl --with-python \
        --with-tcl --with-tclconfig=${final.tcl}/lib \
        --with-system-tzdata=${final.tzdata}/share/zoneinfo
    '')
    (command "postgresql.build" ''
      ${make} all
      ${make} -C contrib all
    '')
    (command "postgresql.install" ''
      ${make} install
      ${make} -C contrib install
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
      dlopenDirectories = final.runtime.dlopenDirectories;
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
    libxslt = true;
    ldap = true;
    nls = true;
    plperl = true;
    plpython = true;
    pltcl = true;
    jit = false;
    numa = false;
    zstd = false;
    lz4 = false;
    pam = true;
    systemd = false;
    osspUuid = false;
    uuidOsspExtension = true;
  };
  meta = {
    description = "PostgreSQL database server, client tools, and development libraries";
    homepage = "https://www.postgresql.org/";
    license = lib.licenses.postgresql;
    platforms = [ "x86_64-linux" ];
    mainProgram = "postgres";
  };
}
