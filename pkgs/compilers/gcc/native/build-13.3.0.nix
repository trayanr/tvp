# Independent GCC 13 source procedure. Standard GCC 13 lib/gcc layout;
# no GCC 16 layout patch or known-result rules. Bootstrap comparison is A.
{
  tvp,
  doCheck ? false,
  bootstrap ? true,
  hardeningDisable ? [ "format" ],
  lib,
  patchelf,
  base,
  bash,
  coreutils,
  src,
  patches,
  gnutar,
  xz,
  gzip,
  patch,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  version,
  glibc,
  binutils,
  gnumake,
  gmp,
  mpfr,
  mpc,
  isl,
  zlib,
  zstd,
  libxcrypt,
  texinfo,
  which,
  perl,
  python,
  pythonConfig,
  file,
  dejagnu,
  expect,
  flock,
  graphviz,
  fonts,
}@args:
final:
let
  # All plans resolve the edited specification, never the original arguments.
  inherit (final)
    base
    bash
    coreutils
    src
    version
    glibc
    binutils
    gnumake
    gmp
    mpfr
    mpc
    isl
    zlib
    zstd
    libxcrypt
    texinfo
    which
    perl
    python
    pythonConfig
    file
    dejagnu
    expect
    flock
    graphviz
    fonts
    gnutar
    xz
    gzip
    patch
    findutils
    sed
    grep
    gawk
    diffutils
    patches
    tuple
    ;
  inherit (tvp.builder) steps outputs;
  libc = final.glibc;
  shell = "${bash}/bin/bash";
  includes = final.libcFlags;
  links = final.linkFlags;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "gcc.${name}";
      cwd = "build";
      run = ''
        validation="$out/nix-support/production"
        mkdir -p "$validation"
        export TVP_SOURCE_ROOT
        status=0
        ${shell} -euc ${lib.escapeShellArg ''
          export SHELL=${shell} CONFIG_SHELL=${shell}
          # CC/CXX remain the resolved, editable base environment bindings.
          export CC_FOR_BUILD="$CC" CXX_FOR_BUILD="$CXX"
          export AR_FOR_BUILD="$AR" AS_FOR_BUILD="$AS" LD_FOR_BUILD="$LD" NM_FOR_BUILD="$NM" RANLIB_FOR_BUILD="$RANLIB"
          export AR_FOR_TARGET="$AR" AS_FOR_TARGET="$AS" LD_FOR_TARGET="$LD" NM_FOR_TARGET="$NM" RANLIB_FOR_TARGET="$RANLIB"
          export OBJDUMP=${binutils}/bin/objdump OBJDUMP_FOR_TARGET=${binutils}/bin/objdump READELF_FOR_TARGET="$READELF"
          # GCC's stage machinery owns CC/CXX/GCC_FOR_TARGET; never inject stage1.
          test -z "''${CC_FOR_TARGET-}''${CXX_FOR_TARGET-}''${GCC_FOR_TARGET-}"
          export CFLAGS="''${CFLAGS:--O2 ${includes}}" CXXFLAGS="''${CXXFLAGS:--O2 ${includes}}"
          export LDFLAGS="''${LDFLAGS:-${links}}"
          flags=(
            "STAGE1_CFLAGS=$CFLAGS"
            "STAGE1_CXXFLAGS=$CXXFLAGS"
            "STAGE1_LDFLAGS=$LDFLAGS"
            "BOOT_CFLAGS=-O2 ${includes} ${links}"
            "BOOT_LDFLAGS=${links} -static-libstdc++ -static-libgcc"
            "CFLAGS_FOR_TARGET=-O2 ${includes} ${links}"
            "CXXFLAGS_FOR_TARGET=-O2 ${includes} ${links}"
            "LDFLAGS_FOR_TARGET=${links}"
            "FLAGS_FOR_TARGET=${includes} ${links}"
            "SYSTEM_HEADER_DIR=${libc}/include"
            "NATIVE_SYSTEM_HEADER_DIR=${libc}/include"
            "LIMITS_H_TEST=true"
          )
          ${run}
        ''} > "$validation/${name}.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$validation/${name}.status"
        if (( status )); then tail -150 "$validation/${name}.log"; exit "$status"; fi
      '';
    };
in
{
  pname = "gcc";
  inherit patchelf;
  configurePrefix = "/tvp/gcc13";
  inherit bootstrap hardeningDisable;
  checkpointScript = ./checkpoint-13.3.0.py;
  finalizerScript = ./finalize.py;
  upstreamRestore = ../tests/restore-16.2.0.py;
  upstreamCapture = ../tests/capture-16.2.0.nix; # Version-neutral raw DejaGNU capture; explicit sourceRoot.
  upstreamSummarizer = ../tests/summarise-upstream.py;
  # Argument values are editable specification data.
  inherit (args)
    base
    bash
    coreutils
    src
    version
    glibc
    binutils
    gnumake
    gmp
    mpfr
    mpc
    isl
    zlib
    zstd
    libxcrypt
    texinfo
    which
    perl
    python
    pythonConfig
    file
    dejagnu
    expect
    flock
    graphviz
    fonts
    gnutar
    xz
    gzip
    patch
    findutils
    sed
    grep
    gawk
    diffutils
    patches
    ;
  tuple = "x86_64-unknown-linux-gnu";
  libcFlags = "-B${libc}/lib/ -isystem ${lib.getDev libc}/include -I${lib.getDev zlib}/include -I${lib.getDev zstd}/include -I${lib.getDev libxcrypt}/include";
  linkFlags =
    "-Wl,-dynamic-linker,${libc}/lib/ld-linux-x86-64.so.2 -Wl,-rpath,$out/lib "
    + lib.concatMapStringsSep " " (p: "-L${lib.getLib p}/lib -Wl,-rpath,${lib.getLib p}/lib") [
      libc
      gmp
      mpfr
      mpc
      isl
      zlib
      zstd
      libxcrypt
    ];
  outputs = [ "out" ];
  runtime.loader = "${libc}/lib/ld-linux-x86-64.so.2";
  environment = {
    tools = [
      coreutils
      binutils
      gnumake
      texinfo
      which
      perl
      python
      file
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
    "--build=${tuple}"
    "--host=${tuple}"
    "--target=${tuple}"
    (if final.bootstrap then "--enable-bootstrap" else "--disable-bootstrap")
    "--enable-languages=c,c++"
    "--disable-multilib"
    "--enable-checking=release"
    "--enable-lto"
    "--enable-plugin"
    "--enable-analyzer"
    "--enable-threads=posix"
    "--disable-nls"
    "--disable-libssp"
    "--with-system-zlib"
    "--with-gmp=${lib.getDev gmp}"
    "--with-mpfr=${lib.getDev mpfr}"
    "--with-mpc=${lib.getDev mpc}"
    "--with-isl=${lib.getDev isl}"
    "--with-zstd=${lib.getDev zstd}"
    "--with-gnu-as"
    "--with-gnu-ld"
    "--with-as=${binutils}/bin/as"
    "--with-ld=${binutils}/bin/ld"
    "--with-build-sysroot=/"
    "--with-native-system-header-dir=${lib.getDev libc}/include"
  ];
  passthru = package: {
    # The passthru callback receives the raw final output, before catalogue
    # decoration. Fresh lowering with empty passthru projects the exact A only;
    # it creates no new stage or reverse dependency on validation.
    validation =
      (import ../tests/upstream-13.3.0.nix {
        inherit tvp lib;
        package = {
          specification = final;
          artifact =
            (import ../../../../lib/owned-build.nix { inherit lib; } (final // { passthru = { }; })).artifact;
        };
      }).execution;
    platform = {
      inherit (final.base.platform) system;
      config = tuple;
      isNative = true;
      linuxHeadersArch = "x86";
      goOS = "linux";
      goArch = "amd64";
      libcLibdirAliases = [ "lib64" ];
      buildPlatform = final.base.platform;
      hostPlatform = final.base.platform;
      targetPlatform = final.base.platform;
      dynamicLinker = "lib/ld-linux-x86-64.so.2";
    };
    # Descriptive raw compiler metadata: no selected-driver wrapper is installed.
    inherit libc;
    bintools = binutils;
    rawCompiler = true;
    runtimeDirectories = [
      "${package}/lib"
      "${package}/lib/gcc/${tuple}/${version}"
      "${libc}/lib"
    ];
  };
  tvp = {
    bootstrap = final.bootstrap;
    compilerInterface = "raw-public";
  };
  meta = {
    description = "GNU C/C++ compiler, unwrapped, with an explicit bootstrap toolchain";
    priority = 10;
    homepage = "https://gcc.gnu.org/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
  plan = [
    {
      name = "gcc.prepare";
      tools = [
        coreutils
        gnutar
        xz
        patch
        python
        findutils
      ];
      run = ''
        mkdir source build
        tar xf ${src} --directory=source --strip-components=1
        cd source
        ${lib.concatMapStringsSep "\n" (p: "patch -Np1 -i ${p}") patches}
        ${python}/bin/python3 -B - "$PWD" <<'PYTHON'
        import pathlib, re, sys
        root = pathlib.Path(sys.argv[1])
        p = root/'gcc/config/i386/linux64.h'
        text, n = re.subn(r'^(#define GLIBC_DYNAMIC_LINKER[A-Z0-9]* )"[^"]*"',
            r'\1"${libc}/lib/ld-linux-x86-64.so.2"', p.read_text(), flags=re.M)
        assert n == 3
        p.write_text(text)
        for p in root.rglob('*'):
            if not p.is_file() or p.is_symlink(): continue
            with p.open('rb') as f: head = f.read(128).split(b'\n')[0]
            if head.startswith((b'#!/bin/sh', b'#! /bin/sh', b'#!/bin/bash')):
                p.write_bytes(b'#!${bash}/bin/bash\n' + p.read_bytes().split(b'\n', 1)[1])
        PYTHON
        touch gcc/gengtype-lex.cc
      '';
    }
    (command "configure" ''
      args=(--prefix=${lib.escapeShellArg final.configurePrefix} --libdir=${lib.escapeShellArg "${final.configurePrefix}/lib"} ${lib.escapeShellArgs final.configureFlags})
      printf '%q ' ${shell} ../source/configure "''${args[@]}" > "$validation/configure-command.txt"
      printf '\n' >> "$validation/configure-command.txt"
      ${shell} ../source/configure "''${args[@]}"
      printf '%s\n' "''${flags[@]}" > "$validation/stage-flags.txt"
    '')
    (command "bootstrap" (
      if final.bootstrap then
        ''
          ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${shell} "''${flags[@]}" bootstrap
          test -f compare
          test ! -f stage2-lean
          test ! -f .bad_compare
          rm compare
          ${gnumake}/bin/make SHELL=${shell} "''${flags[@]}" compare > "$validation/bootstrap-compare.log" 2>&1
          grep -Fx 'Comparison successful.' "$validation/bootstrap-compare.log"
          cp stage_final "$validation/stage_final"
          cp config.log "$validation/config.log"
          find stage2-gcc -name '*.o' -type f | sort > "$validation/stage2-objects.txt"
          test -s "$validation/stage2-objects.txt"
          while read -r file; do sha256sum "$file"; done < "$validation/stage2-objects.txt" > "$validation/stage2-objects.sha256"
          ${gnumake}/bin/make SHELL=${shell} "''${flags[@]}" stage3-start > "$validation/stage3-start.log" 2>&1
          find . -name config.log -o -name config.status | while read -r file; do
            mkdir -p "$validation/configure/$(dirname "$file")"
            cp "$file" "$validation/configure/$file"
          done
        ''
      else
        ''
          ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${shell} "''${flags[@]}" all
          cp config.log "$validation/config.log"
        ''
    ))
    (command "install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${shell} "''${flags[@]}" DESTDIR="$PWD/install-root" install
      cp -a "install-root${final.configurePrefix}/." "$out/"
      if test -d "$out/lib64" && ! test -L "$out/lib64"; then
        cp -a "$out/lib64/." "$out/lib/"
        rm -rf "$out/lib64"
        ln -s lib "$out/lib64"
      fi
      ln -sf gcc "$out/bin/cc"
      ln -sf g++ "$out/bin/c++"
      find "$out" -type f | sort > "$validation/installed-files.txt"
      for file in "$out/bin/gcc" "$out/libexec/gcc/${tuple}/${version}/"{cc1,cc1plus,collect2,lto1,lto-wrapper} "$out/libexec/gcc/${tuple}/${version}/liblto_plugin.so"; do
        test -f "$file"
        ${binutils}/bin/readelf -W -l -d "$file" >> "$validation/installed-elf.txt"
      done
      "$out/bin/gcc" -dumpspecs > "$validation/builtin.specs"
    '')
    (command "checkpoint" ''
      ${python}/bin/python3 -B ${final.checkpointScript} save "$TVP_SOURCE_ROOT" "$out/nix-support/upstream-build-tree"
    '')
    (steps.split "gcc.finalize")
    {
      name = "gcc.copy-public";
      tools = [ coreutils ];
      run = ''
        mkdir -p "$out"
        for directory in bin include lib lib64 libexec share; do
          if test -e "$TVP_ARTIFACT_ROOT/$directory" || test -L "$TVP_ARTIFACT_ROOT/$directory"; then
            ${coreutils}/bin/cp -a --no-preserve=ownership "$TVP_ARTIFACT_ROOT/$directory" "$out/"
          fi
        done
        ${coreutils}/bin/chmod -R u+w "$out"
      '';
    }
    {
      name = "gcc.relocate-public";
      tools = [
        python
        binutils
        final.patchelf
      ];
      run = ''${python}/bin/python3 -B ${final.finalizerScript} "$out" "$TVP_ARTIFACT_ROOT" ${lib.escapeShellArg final.configurePrefix} ${binutils}/bin/readelf ${final.patchelf}/bin/patchelf ${../../../../pkgs/libraries/libxml2/ordinary/elf.py}'';
    }
    (outputs.interpreters {
      inherit python binutils;
      inherit (final) patchelf;
      paths = [
        "bin"
        "libexec"
        "lib"
      ];
      loader = final.runtime.loader;
    })
    (outputs.checkPaths {
      inherit python binutils;
      inherit (final) patchelf;
      paths = [
        "bin"
        "libexec"
        "lib"
      ];
    })
  ];
}
