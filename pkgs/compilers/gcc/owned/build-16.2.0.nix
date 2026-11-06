# Full C/C++ native three-stage bootstrap and matching target runtimes, starting
# at 16.2.0. The reduced compiler-only checkpoint is a different procedure.
# This first qualification deliberately runs checks in the construction tree:
# no unproven configured-tree relocation or test-tool cache isolation is claimed.
{
  lib,
  base,
  bash,
  coreutils,
  source,
  version,
  libc,
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
  tools,
}:
final:
let
  tuple = "x86_64-unknown-linux-gnu";
  shell = "${bash}/bin/bash";
  libraries = [
    libc
    gmp
    mpfr
    mpc
    isl
    zlib
    zstd
    libxcrypt
  ];
  includes = "-B${libc}/lib/ -idirafter ${libc}/include -I${zlib}/include -I${zstd}/include -I${libxcrypt}/include";
  links =
    "-Wl,-dynamic-linker,${libc}/lib/ld-linux-x86-64.so.2 -Wl,-rpath,$out/lib "
    + lib.concatMapStringsSep " " (p: "-L${p}/lib -Wl,-rpath,${p}/lib") libraries;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "gcc.${name}";
      cwd = "build";
      run = ''
        mkdir -p "$evidence"
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
        ''} > "$evidence/${name}.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$evidence/${name}.status"
        if (( status )); then tail -150 "$evidence/${name}.log"; exit "$status"; fi
      '';
    };
in
{
  pname = "source-full-gcc";
  inherit
    version
    base
    bash
    coreutils
    ;
  src = source;
  outputs = [
    "out"
    "evidence"
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
    ] ++ tools;
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
  plan = [
    {
      name = "gcc.prepare";
      run = ''
        cp -pr ${final.src} source
        chmod -R u+w source
        mkdir -p build
      '';
    }
    (command "configure" ''
      args=(--prefix="$out" --libdir="$out/lib" ${lib.escapeShellArgs final.configureFlags})
      printf '%q ' ${shell} ../source/configure "''${args[@]}" > "$evidence/configure-command.txt"
      printf '\n' >> "$evidence/configure-command.txt"
      ${shell} ../source/configure "''${args[@]}"
      printf '%s\n' "''${flags[@]}" > "$evidence/stage-flags.txt"
    '')
    (command "bootstrap" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${shell} "''${flags[@]}" bootstrap
      test -f compare
      test ! -f stage2-lean
      test ! -f .bad_compare
      rm compare
      ${gnumake}/bin/make SHELL=${shell} "''${flags[@]}" compare > "$evidence/comparison.log" 2>&1
      grep -Fx 'Comparison successful.' "$evidence/comparison.log"
      cp stage_final "$evidence/stage_final"
      find stage2-gcc -name '*.o' -type f | sort > "$evidence/stage2-objects.txt"
      test -s "$evidence/stage2-objects.txt"
      while read -r file; do sha256sum "$file"; done < "$evidence/stage2-objects.txt" > "$evidence/stage2-objects.sha256"
      ${gnumake}/bin/make SHELL=${shell} "''${flags[@]}" stage3-start > "$evidence/stage3-start.log" 2>&1
      find . -name config.log -o -name config.status | while read -r file; do
        mkdir -p "$evidence/configure/$(dirname "$file")"
        cp "$file" "$evidence/configure/$file"
      done
    '')
    (command "check" ''
      mkdir -p boards "$PWD/home" "$PWD/cache" "$evidence/raw"
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
      printf '%s\n' "HOSTCC=$CC" "HOSTCXX=$CXX" "SHELL=$SHELL" "FONTCONFIG_FILE=$FONTCONFIG_FILE" > "$evidence/test-environment.txt"
      check_status=0
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" -k SHELL=${shell} "''${flags[@]}" \
        "CXXFLAGS_FOR_TARGET=-O2 -g ${includes} ${links}" \
        RUNTESTFLAGS=--target_board=tvp \
        check-gcc check-target-libstdc++-v3 check-target-libgomp \
        check-target-libatomic check-target-libitm check-target-libquadmath \
        check-target-libsanitizer > "$evidence/make-check.log" 2>&1 || check_status=$?
      printf '%s\n' "$check_status" > "$evidence/make-check.status"
      find . -type f \( -name '*.sum' -o -name '*.log' \) -exec cp --parents {} "$evidence/raw" \;
      ${python}/bin/python3 -B ${../tests/summarise-upstream.py} "$evidence/raw" > "$evidence/outcomes.txt"
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
      find "$out" -type f | sort > "$evidence/installed-files.txt"
      for file in "$out/bin/gcc" "$out/libexec/gcc/${tuple}/${version}/"{cc1,cc1plus,collect2,lto1,lto-wrapper} "$out/libexec/gcc/${tuple}/${version}/liblto_plugin.so"; do
        test -f "$file"
        ${binutils}/bin/readelf -W -l -d "$file" >> "$evidence/installed-elf.txt"
      done
      "$out/bin/gcc" -dumpspecs > "$evidence/builtin.specs"
    '')
  ];
}
