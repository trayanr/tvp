# Full public native 2.39 profile, independently constructed on the owned base.
# The reduced bootstrap sysroot is not this package's installed interface.
{
  tvp,
  lib,
  platforms,
  base,
  bash,
  coreutils,
  src,
  version,
  patches,
  gcc,
  binutils,
  linuxHeaders,
  bison,
  python3Minimal,
  perl,
  gnumake,
  gnutar,
  xz,
  gzip,
  patch,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
}@args:
final:
let
  inherit (final)
    base
    bash
    coreutils
    src
    version
    patches
    gcc
    binutils
    linuxHeaders
    bison
    python3Minimal
    perl
    gnumake
    gnutar
    xz
    gzip
    patch
    findutils
    sed
    grep
    gawk
    diffutils
    ;
  shell = "${bash}/bin/bash";
  platform = platforms.mkNative {
    buildPlatform = base.platform;
    hostPlatform = base.platform;
    targetPlatform = base.platform;
  };
  command =
    name: cwd: run:
    (base.environment final.environment)
    // {
      name = "glibc.${name}";
      inherit cwd;
      run = ''
        export SHELL=${shell} CONFIG_SHELL=${shell} BASH_SHELL=${shell}
        # BUILD_CC is a separate build-machine role. It uses its own configured
        # base sysroot; target CC must remain raw for glibc's self construction.
        export BUILD_CC=${lib.escapeShellArg final.buildCC}
        unset NIX_CFLAGS_COMPILE NIX_CFLAGS_LINK NIX_LDFLAGS NIX_HARDENING_ENABLE
        unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH OBJC_INCLUDE_PATH LIBRARY_PATH
        unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS GCC_EXEC_PREFIX COMPILER_PATH
        export CC=${lib.escapeShellArg final.targetCC} CXX=${lib.escapeShellArg final.targetCXX}
        export AR=${binutils}/bin/ar AS=${binutils}/bin/as LD=${binutils}/bin/ld
        export NM=${binutils}/bin/nm OBJCOPY=${binutils}/bin/objcopy
        export OBJDUMP=${binutils}/bin/objdump RANLIB=${binutils}/bin/ranlib
        export READELF=${binutils}/bin/readelf
        export PYTHON=${python3Minimal}/bin/python3 BISON=${bison}/bin/bison
        export PERL=${perl}/bin/perl
        export CFLAGS=${lib.escapeShellArg final.cflags} CXXFLAGS=${lib.escapeShellArg final.cflags}
        ${run}
      '';
    };
in
{
  pname = "glibc";
  inherit (args)
    base
    bash
    coreutils
    src
    version
    patches
    gcc
    binutils
    linuxHeaders
    bison
    python3Minimal
    perl
    gnumake
    gnutar
    xz
    gzip
    patch
    findutils
    sed
    grep
    gawk
    diffutils
    ;
  inherit platform;
  outputs = [
    "out"
    "bin"
  ];
  buildCC = "${base.compiler}/bin/cc";
  targetCC = "${gcc}/bin/gcc -B${binutils}/bin/ -B${gcc.tvp.deps.glibc}/lib/";
  targetCXX = "${gcc}/bin/g++ -B${binutils}/bin/ -B${gcc.tvp.deps.glibc}/lib/";
  cflags = "-O2";
  environment = {
    tools = [
      coreutils
      bash
      gcc
      binutils
      bison
      python3Minimal
      perl
      gnumake
      gnutar
      xz
      gzip
      patch
      findutils
      sed
      grep
      gawk
      diffutils
    ];
    libraries = [ ];
  };
  configureFlags = [
    "--build=${base.platform.config}"
    "--host=${base.platform.config}"
    "--with-headers=${linuxHeaders}/include"
    "--enable-kernel=3.10.0"
    "--disable-werror"
    "--enable-stack-protector=strong"
    "--enable-bind-now"
    "--enable-static-pie"
  ];
  makeFlags = [ "OBJCOPY=${binutils}/bin/objcopy" ];
  passthru = package: {
    inherit platform;
    # New owned API: { base; bash; perl; } are explicit, with optional editable
    # preparation providers. No stdenv or future shell enters libc construction.
    mkTools =
      {
        base,
        bash,
        perl,
        coreutils ? final.coreutils,
        python3Minimal ? final.python3Minimal,
      }:
      import ./tools.nix {
        inherit
          tvp
          lib
          base
          bash
          perl
          coreutils
          python3Minimal
          ;
        glibc = package // {
          inherit (final) version;
        };
        buildPerl = final.perl;
        inherit (final) sed grep gawk;
      };
  };
  meta = {
    description = "GNU C Library";
    homepage = "https://www.gnu.org/software/libc/";
    license = lib.licenses.lgpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
  plan = [
    (
      (tvp.builder.steps.unpack {
        inherit src xz findutils;
        tar = gnutar;
        compression = "xz";
      })
      // {
        tools = [
          coreutils
          gnutar
          xz
          findutils
        ];
      }
    )
    (command "prepare" "source" ''
      ${lib.concatMapStringsSep "\n" (p: "${patch}/bin/patch -Np1 -i ${p}") patches}
      ${python3Minimal}/bin/python3 -B ${./prepare.py} "$PWD" "$out" ${shell}
      printf '%s\n' 'LDFLAGS-nscd += -static-libgcc' >> nscd/Makefile
      mkdir ../build
    '')
    (command "configure" "build" ''
      ${shell} ../source/configure --prefix="$out" --libdir="$out/lib" \
        --sysconfdir="$out/etc" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" "build" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${shell} ${lib.escapeShellArgs final.makeFlags}
    '')
    (command "install" "build" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${shell} \
        ${lib.escapeShellArgs final.makeFlags} sysconfdir="$out/etc" install
    '')
    (command "finalize" "build" ''
      ${lib.concatMapStringsSep "\n" (dir: ''ln -sT lib "$out/${dir}"'') final.platform.libcLibdirAliases}
      mkdir -p "$out/lib/locale"
      I18NPATH="$TVP_SOURCE_ROOT/source/localedata" \
        "$out/bin/localedef" --no-archive -i C -f UTF-8 "$out/lib/locale/C.utf8"
      cp -rs ${linuxHeaders}/include/* "$out/include/"
      mkdir -p "$bin" "$out/share/licenses/glibc"
      mv "$out/bin" "$bin/bin"
      mv "$out/sbin" "$bin/sbin"
      cp ../source/COPYING* ../source/LICENSES "$out/share/licenses/glibc/"
    '')
    # Bind installed shell scripts without touching ELF, loader or libc search
    # paths. A later mkTools call can bind to the future runtime interpreters.
    {
      name = "glibc.scripts";
      tools = [
        coreutils
        python3Minimal
      ];
      run = ''
        ${python3Minimal}/bin/python3 -B ${./.}/rebind-tools.py "$bin" \
          ${shell} ${perl}/bin/perl ${perl}/bin/perl \
          ${lib.escapeShellArg "${coreutils}/bin:${sed}/bin:${grep}/bin:${gawk}/bin"}
      '';
    }
  ];
}
