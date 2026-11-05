# Compiler only: GNU generators and host, existing matching target runtimes.
{
  tvp,
  lib,
  base,
  bash,
  coreutils,
  profile,
  python,
  binutils,
  gnumake,
  tools,
  source,
  libiberty,
  libbacktrace,
  gmp,
  mpfr,
  mpc,
}:
final:
let
  tuple = "x86_64-unknown-linux-gnu";
  rt = "${profile.libgcc}/lib/gcc/${tuple}/16.2.0";
  shell = "${bash}/bin/bash";
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "gcc.${name}";
      cwd = "build";
      run = ''
        mkdir -p "$evidence"
        export SHELL=${shell} CONFIG_SHELL=${shell}
        export CC=${final.base.stdenv.cc}/bin/gcc CXX=${final.base.stdenv.cc}/bin/g++
        export CC_FOR_BUILD="$CC" CXX_FOR_BUILD="$CXX" CC_FOR_TARGET="$CC" CXX_FOR_TARGET="$CXX" GCC_FOR_TARGET="$CC"
        export AR=${binutils}/bin/ar NM=${binutils}/bin/nm RANLIB=${binutils}/bin/ranlib
        export OBJDUMP=${binutils}/bin/objdump READELF=${binutils}/bin/readelf STRIP=${binutils}/bin/strip
        export AS=${binutils}/bin/as LD=${binutils}/bin/ld
        export AR_FOR_BUILD="$AR" NM_FOR_BUILD="$NM" RANLIB_FOR_BUILD="$RANLIB" OBJDUMP_FOR_BUILD="$OBJDUMP" AS_FOR_BUILD="$AS" LD_FOR_BUILD="$LD"
        export AR_FOR_TARGET="$AR" NM_FOR_TARGET="$NM" RANLIB_FOR_TARGET="$RANLIB" OBJDUMP_FOR_TARGET="$OBJDUMP" AS_FOR_TARGET="$AS" LD_FOR_TARGET="$LD" READELF_FOR_TARGET="$READELF"
        export CFLAGS=-O1 CXXFLAGS=-O1 CFLAGS_FOR_BUILD=-O1 CXXFLAGS_FOR_BUILD=-O1 LDFLAGS_FOR_BUILD=
        export LDFLAGS="-Wl,-rpath-link,${profile.libc}/lib -Wl,-rpath,${mpc}/lib -Wl,-rpath,${mpfr}/lib -Wl,-rpath,${gmp}/lib"
        export gccng_skip_target_lib_config=y
        status=0
        ${shell} -euc ${lib.escapeShellArg run} > "$evidence/${name}.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$evidence/${name}.status"
        if (( status )); then cat "$evidence/${name}.log"; exit "$status"; fi
      '';
    };
in
{
  pname = "source-native-gcc";
  version = "16.2.0";
  src = source;
  inherit base bash coreutils;
  outputs = [
    "out"
    "evidence"
  ];
  environment.tools = [
    binutils
    gnumake
  ] ++ tools;
  plan = [
    {
      name = "gcc.prepare";
      run = ''
        cp -pr ${final.src} source
        chmod -R u+w source
        mkdir -p build/libbacktrace/.libs build/libiberty/pic build/build-${tuple}/libiberty
        cp ${libbacktrace}/lib/libbacktrace.a build/libbacktrace/.libs/
        cp ${libbacktrace}/lib/*.la build/libbacktrace/
        cp ${libbacktrace}/include/*.h build/libbacktrace/
        cp ${libiberty}/lib/libiberty.a build/libiberty/
        cp ${libiberty}/lib/libiberty_pic.a build/libiberty/pic/libiberty.a
        touch build/libiberty/stamp-noasandir build/libiberty/stamp-h build/libiberty/stamp-picdir
        cp ${libiberty}/lib/libiberty.a build/build-${tuple}/libiberty/
      '';
    }
    (command "configure" ''
      ${shell} ../source/configure --prefix="$out" \
        --build=${tuple} --host=${tuple} --target=${tuple} \
        --disable-bootstrap --disable-multilib --disable-nls --disable-analyzer \
        --disable-decimal-float --disable-gcov --disable-install-libiberty \
        --disable-libssp --disable-plugin --disable-plugins --disable-lto \
        --enable-languages=c,c++ --enable-threads=posix \
        --without-headers --without-included-gettext --without-isl \
        --with-gnu-as --with-gnu-ld --with-as=${binutils}/bin/as --with-ld=${binutils}/bin/ld \
        --with-sysroot=${profile.libc} --with-native-system-header-dir=/include \
        --with-gxx-include-dir=${profile.libstdcxx}/include/c++/16.2.0 \
        --with-gmp=${gmp} --with-mpfr=${mpfr} --with-mpc=${mpc}
      sed -i '/TOPLEVEL_CONFIGURE_ARGUMENTS=/d' Makefile
    '')
    (command "build" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${shell} GCC_FOR_TARGET='./xgcc -B./' all-gcc
      mkdir -p "$evidence/generators"
      for tool in gcc/build/gen*; do
        test -f "$tool" && test -x "$tool" || continue
        ${binutils}/bin/readelf -W -l -d "$tool" > "$evidence/generators/$(basename "$tool").elf"
      done
      LD_DEBUG=libs gcc/build/genmodes > "$evidence/generators/genmodes.out" 2> "$evidence/generators/genmodes.loader"
    '')
    (command "install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${shell} GCC_FOR_TARGET='./xgcc -B./' install-strip-gcc
      rm -rf "$out/libexec/gcc/"*/*/install-tools "$out/lib/gcc/"*/*/install-tools
      rm -rf "$out/share/gcc-"*/python "$out/share/man" "$out/share/info"
      for file in ${rt}/*; do
        test -f "$file" || continue
        ln -sf "$file" "$out/lib/gcc/${tuple}/16.2.0/"
      done
      for header in ${rt}/include/*; do
        test -f "$header" || continue
        ln -s "$header" "$out/lib/gcc/${tuple}/16.2.0/include/$(basename "$header")"
      done
      "$out/bin/gcc" -dumpspecs > specs
      sed -i '/^\*link:$/ { n; s|^|--disable-new-dtags -rpath-link ${profile.libc}/lib -rpath-link ${rt} -rpath-link ${profile.libstdcxx}/lib -rpath ${profile.libc}/lib -rpath ${rt} -rpath ${profile.libstdcxx}/lib |; }' specs
      sed -i '/^\*link_libgcc:$/ { n; s|^|-L${profile.libstdcxx}/lib -L${rt} |; }' specs
      cp specs "$out/lib/gcc/${tuple}/16.2.0/specs"
      mkdir -p "$out/${tuple}/bin" "$out/share/licenses/gcc"
      for tool in as ld ar nm ranlib strip objdump readelf; do
        ln -s ${binutils}/bin/"$tool" "$out/${tuple}/bin/$tool"
      done
      cp gcc/config.log gcc/auto-host.h "$evidence/"
      cp ../source/COPYING* "$out/share/licenses/gcc/"
    '')
  ];
}
