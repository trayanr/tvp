# Public GCC 16.2.0 starts an independent full native C/C++ procedure.
# Keep raw tools for libc construction, including static PIE and -nostdlib.
# Construction-tree upstream checks and the real three-stage comparison remain
# mandatory; the restricted selected consumer driver is a separate interface.
{
  lib,
  base,
  bash,
  coreutils,
  src,
  layoutPatch,
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
    layoutPatch
    patches
    tuple
    ;
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
    layoutPatch
    patches
    ;
  tuple = "x86_64-unknown-linux-gnu";
  libcFlags = "-B${libc}/lib/ -idirafter ${libc}/include -I${zlib}/include -I${zstd}/include -I${libxcrypt}/include";
  linkFlags =
    "-Wl,-dynamic-linker,${libc}/lib/ld-linux-x86-64.so.2 -Wl,-rpath,$out/lib "
    + lib.concatMapStringsSep " " (p: "-L${p}/lib -Wl,-rpath,${p}/lib") [
      libc
      gmp
      mpfr
      mpc
      isl
      zlib
      zstd
      libxcrypt
    ];
  outputs = [
    "out"
    "validation"
  ];
  environment = {
    tools = [
      binutils
      gnumake
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
    "--enable-bootstrap"
    "--enable-languages=c,c++"
    "--disable-multilib"
    "--enable-checking=release"
    "--enable-lto"
    "--enable-plugin"
    "--enable-analyzer"
    "--enable-threads=posix"
    "--disable-nls"
    "--disable-libssp"
    "--without-included-gettext"
    "--with-system-zlib"
    "--with-gmp=${gmp}"
    "--with-mpfr=${mpfr}"
    "--with-mpc=${mpc}"
    "--with-isl=${isl}"
    "--with-zstd=${zstd}"
    "--with-gnu-as"
    "--with-gnu-ld"
    "--with-as=${binutils}/bin/as"
    "--with-ld=${binutils}/bin/ld"
    "--with-sysroot=${libc}"
    "--with-native-system-header-dir=/include"
  ];
  passthru = package: {
    platform = {
      system = final.base.platform.system;
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
    bootstrap = true;
    compilerInterface = "raw-public";
  };
  meta = {
    description = "GNU Compiler Collection, full native C/C++ bootstrap";
    homepage = "https://gcc.gnu.org/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
  plan = [
    {
      name = "gcc.prepare";
      tools = [
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
        patch -Np1 -i ${layoutPatch}
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
      args=(--prefix="$out" --libdir="$out/lib" ${lib.escapeShellArgs final.configureFlags})
      printf '%q ' ${shell} ../source/configure "''${args[@]}" > "$validation/configure-command.txt"
      printf '\n' >> "$validation/configure-command.txt"
      ${shell} ../source/configure "''${args[@]}"
      printf '%s\n' "''${flags[@]}" > "$validation/stage-flags.txt"
    '')
    (command "bootstrap" ''
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
    '')
    (command "check" ''
      mkdir -p boards "$PWD/home" "$PWD/cache" "$validation"
      cat > boards/tvp.exp <<'BOARD'
      load_base_board_description "unix"
      unset_board_info isremote
      set_board_info isremote 0
      set_board_info cflags " -B${libc}/lib/ -idirafter ${libc}/include -L${libc}/lib -Wl,-rpath,${libc}/lib "
      set_board_info ldflags " -B${libc}/lib/ -L${libc}/lib -Wl,-rpath,${libc}/lib "
      BOARD
      cat > site-tvp.exp <<SITE
      lappend boards_dir "$PWD/boards"
      set HOSTCC "$CC"
      set HOSTCXX "$CXX"
      SITE
      export DEJAGNU="$PWD/site-tvp.exp" HOME="$PWD/home" XDG_CACHE_HOME="$PWD/cache"
      export FONTCONFIG_FILE=${fonts}/etc/fonts/fonts.conf PYTHONNOUSERSITE=1
      export PYTHONPATH="$TVP_SOURCE_ROOT/source/gcc/testsuite''${PYTHONPATH:+:$PYTHONPATH}"
      printf '%s\n' "HOSTCC=$CC" "HOSTCXX=$CXX" "SHELL=$SHELL" "FONTCONFIG_FILE=$FONTCONFIG_FILE" > "$validation/test-environment.txt"
      check_status=0
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" -k SHELL=${shell} "''${flags[@]}" \
        "CXXFLAGS_FOR_TARGET=-O2 -g ${includes} ${links}" \
        RUNTESTFLAGS=--target_board=tvp \
        check-gcc check-target-libstdc++-v3 check-target-libgomp \
        check-target-libatomic check-target-libitm check-target-libquadmath \
        check-target-libsanitizer > "$validation/make-check.log" 2>&1 || check_status=$?
      head -n 1 "$validation/make-check.log" > "$validation/invocation.txt"
      printf '%s\n' "$check_status" > "$validation/make-check.exit"
      find . -type f \( -name '*.sum' -o -name '*.log' \) -exec cp --parents {} "$validation" \;
      ${python}/bin/python3 -B ${../tests/summarise-upstream.py} "$validation" > "$validation/outcomes.txt"
      # The qualification endpoint audits complete raw summaries and failures.
      # Retaining make's nonzero status is not an upstream pass assertion.
    '')
    (command "install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${shell} "''${flags[@]}" install
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
  ];
}
