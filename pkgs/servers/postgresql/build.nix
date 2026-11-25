# PostgreSQL 14 and later use the world-bin target for core and contrib.
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
  llvm,
  lz4,
  numactl ? null,
  openldap,
  openssl,
  perl,
  python,
  readline,
  tcl,
  tzdata,
  zlib,
  zstd ? null,
  bison ? null,
  flex ? null,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  # The selected binutils can put wall-clock timestamps in archives and their indexes.
  make = ''
    ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash \
      AROPT=crsD RANLIB="$RANLIB -D"'';
  elfPaths = [
    "bin"
    "lib"
  ];
  # These releases backport the ORC allocation interface required by LLVM 22+.
  firstLLVM22 = {
    "14" = "14.23";
    "15" = "15.18";
    "16" = "16.14";
    "17" = "17.10";
    "18" = "18.4";
    "19" = "19.0";
  };
  major = lib.versions.major final.version;
  withLLVM = lib.versionAtLeast final.version (firstLLVM22.${major} or final.version);
  withNUMA = final.numactl != null && lib.versionAtLeast final.version "18";
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
    final.lz4
    final.openldap
    final.openssl
    final.python
    final.readline
    # Configure's Readline link probe also needs its selected terminal library.
    final.readline.tvp.deps.ncurses
    final.tcl
    final.zlib
  ]
  ++ lib.optional (final.zstd != null) final.zstd
  ++ lib.optional withNUMA final.numactl
  ++ lib.optional withLLVM final.llvm;
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
    llvm
    lz4
    numactl
    openldap
    openssl
    python
    readline
    tcl
    tzdata
    zlib
    zstd
    bison
    flex
    perl
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
    ++ lib.filter (tool: tool != null) [
      final.bison
      final.flex
    ]
    ++ lib.optional withLLVM final.llvm;
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
      ${lib.optionalString withLLVM ''
        export LLVM_CONFIG=${final.llvm}/bin/llvm-config CLANG=${final.llvm}/bin/clang
      ''}
      # OpenLDAP 2.5 merged the threaded libldap_r implementation into libldap.
      grep -Fq -- '-lldap_r' configure
      sed -i 's/-lldap_r\>/-lldap/g' configure
      "$CONFIG_SHELL" ./configure --prefix="$out" --libdir="$out/lib" \
        CFLAGS="''${CFLAGS:--O2} -std=gnu17" \
        --enable-nls --with-ssl=openssl --with-gssapi --with-icu --with-libxml --with-libxslt \
        --with-ldap --with-pam --with-uuid=e2fs --with-perl --with-python \
        --with-tcl --with-tclconfig=${final.tcl}/lib \
        --with-lz4${
          lib.optionalString (final.zstd != null) " --with-zstd"
        }${lib.optionalString withLLVM " --with-llvm"}${lib.optionalString withNUMA " --with-libnuma"} \
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
    jit = withLLVM;
    numa = withNUMA;
    zstd = final.zstd != null;
    lz4 = true;
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
