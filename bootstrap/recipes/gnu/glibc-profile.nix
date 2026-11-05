# Selected libc capabilities, deliberately staged on the previous GNU Bash.
# Keep glibc.nix and its reduced sysroot identity unchanged.
{
  scope,
  cross,
  bridge,
  priorShell,
}:
let
  inherit (scope) bash fetchurl;
  shell = "${bash}/bin/bash";
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/glibc/glibc-2.39.tar.xz";
    hash = "sha256-93vUfPgXDFc2Wue/hmlsEYrbOxINMlnGTFAtPcHi2SY=";
  };
in
bash.runCommand "tvp-bootstrap-glibc-2.39-capabilities"
  {
    version = "2.39";
    outputs = [
      "out"
      "evidence"
    ];
    nativeBuildInputs = with scope; [
      binutils
      gnumake-musl
      gnused
      build-grep
      gawk
      diffutils
      findutils
      build-python
      build-bison
      build-m4
      gnutar-latest
      xz
      gnupatch
    ];
  }
  ''
    tar xf ${src}
    taskSrc="$PWD/glibc-2.39"
    # GCC16 -O2 reports the existing documented false positives. Extend only
    # glibc's four local diagnostic regions beyond their -Os condition.
    (cd "$taskSrc"; patch -p1 -i ${./glibc-fnmatch-gcc16.patch})
    mkdir -p "$evidence"
    ${scope.build-python}/bin/python3 ${../../gnu-libc-shell-prepare.py} \
      "$taskSrc" ${priorShell}/bin/sh > "$evidence/shell-source.json"
    # Do not consult the host's preload file, cache, or default library paths.
    sed -i 's|"/etc/ld.so.preload"|"'"$out"'/etc/ld.so.preload"|' "$taskSrc/elf/rtld.c"
    mkdir build
    cd build
    # Glibc Makeconfig explicitly excludes EH from its bootstrap gnulib.
    # Its module helper nevertheless passes -static-libgcc to the driver. Bind
    # that driver's implicit runtime to real core arithmetic, never an EH alias.
    printf '%s\n' '*libgcc:' '-lgcc' > bootstrap-core.specs
    export CC="${cross}/bin/x86_64-unknown-linux-gnu-gcc -specs=$PWD/bootstrap-core.specs -B${bridge}/lib/"
    export BUILD_CC=${scope.gcc-latest}/bin/gcc CXX=false
    export AR=${scope.binutils}/bin/ar AS=${scope.binutils}/bin/as
    export LD=${scope.binutils}/bin/ld NM=${scope.binutils}/bin/nm
    export OBJCOPY=${scope.binutils}/bin/objcopy OBJDUMP=${scope.binutils}/bin/objdump
    export RANLIB=${scope.binutils}/bin/ranlib
    export PYTHON=${scope.build-python}/bin/python3 BISON=${scope.build-bison}/bin/bison
    export CFLAGS="-O2" LDFLAGS="-L${bridge}/lib"
    ${shell} "$taskSrc/configure" --prefix="$out" \
      --build=x86_64-unknown-linux-musl --host=x86_64-unknown-linux-gnu \
      --with-headers=${scope.linux-headers}/include \
      --disable-nscd --disable-build-nscd --disable-profile --disable-timezone-tools \
      --disable-mathvec
    make -j "$NIX_BUILD_CORES" SHELL=${shell} \
      sysdep-LDFLAGS="-L${bridge}/lib -Wl,-t,-t"
    make -j "$NIX_BUILD_CORES" SHELL=${shell} INSTALL_UNCOMPRESSED=yes install
    # Retain precisely the three locale/conversion binaries and iconvconfig.
    # Keep the complete installed converter metadata/module set until measured.
    for file in "$out"/bin/*; do
      case "$(basename "$file")" in locale|localedef|iconv) ;; *) rm -f "$file" ;; esac
    done
    for file in "$out"/sbin/*; do
      case "$(basename "$file")" in iconvconfig) ;; *) rm -f "$file" ;; esac
    done
    rm -rf "$out/libexec" "$out/share/info" "$out/share/locale"
    # These are matching newly built G tools, using their compiled-in defaults.
    mkdir -p "$out/lib/locale"
    env -i "$out/bin/localedef" --no-archive -i "$out/share/i18n/locales/C" \
      -f "$out/share/i18n/charmaps/UTF-8" "$out/lib/locale/C.UTF-8"
    env -i "$out/sbin/iconvconfig"
    # Locale sources/charmaps are build data, not an all-locales runtime promise.
    rm -rf "$out/share/i18n"
    # GNU ld rebases absolute names in scripts under --sysroot. Store-prefix
    # names would be rebased twice; use sysroot-rooted names in this data file.
    sed -i "s|$out/|/|g" "$out/lib/libc.so"
    ln -s lib "$out/lib64"
    for dir in ${scope.linux-headers}/include/*; do
      test -e "$out/include/$(basename "$dir")" || ln -s "$dir" "$out/include/"
    done
    mkdir -p "$out/share/licenses/glibc" "$evidence"
    cp "$taskSrc"/COPYING* "$taskSrc/LICENSES" "$out/share/licenses/glibc/"
    cp config.log config.make "$evidence/"
    ${scope.binutils}/bin/readelf -l -d "$out/lib/libc.so.6" > "$evidence/libc.elf"
  ''
