# Minimal GNU host tools. Build generators still execute on M.
{ scope, cc }:
let
  inherit (scope) bash fetchurl;
  shell = "${bash}/bin/bash";
  run =
    name: command:
    bash.runCommand name
      {
        nativeBuildInputs = with scope; [
          binutils
          gnumake-musl
          gnused
          build-grep
          gawk
          diffutils
          findutils
          gnutar-latest
          gzip
          bzip2
          xz
          gnupatch
        ];
      }
      ''
            export CC=${cc}/bin/gcc CXX=${cc}/bin/g++
            export CC_FOR_BUILD=${scope.gcc-latest}/bin/gcc CXX_FOR_BUILD=${scope.gcc-latest}/bin/g++
            export CFLAGS=-O2 CXXFLAGS=-O2 STRIP=${scope.binutils}/bin/strip
        export AR=${scope.binutils}/bin/ar RANLIB=${scope.binutils}/bin/ranlib
            ${command}
      '';
  bashSrc = fetchurl {
    url = "mirror://gnu/bash/bash-5.3.tar.gz";
    hash = "sha256-DVzYaWX4aaJs9k9Lcb57lvkKO6iz104n6OnZ1VUPMbo=";
  };
  binutilsSrc = fetchurl {
    url = "https://mirrors.kernel.org/gnu/binutils/binutils-2.42.tar.xz";
    hash = "sha256-9uTUH9X8d4sGt4kUV7NiDaXs6hAGxqSkGumYEJ+FqAA=";
  };
in
{
  gnu-bash = run "tvp-bootstrap-gnu-bash-5.3" ''
    tar xf ${bashSrc}
    cd bash-5.3
    patch -p1 -i ${../bash/mksignames-flush.patch}
    # Bash's cross default substitutes a generic getcwd and fails in sandbox
    # directories. Measure its exact GNU-libc getcwd(0,0) premise here; this
    # G executable runs through the owned loader on the same Linux kernel.
    printf '%s\n' '#include <unistd.h>' '#include <stdlib.h>' \
      'int main(void) { char *p=getcwd(0,0); if (!p) return 1; free(p); return 0; }' > getcwd-probe.c
    $CC getcwd-probe.c -o getcwd-probe
    env -i ./getcwd-probe
    export bash_cv_getcwd_malloc=yes
    ${shell} ./configure --prefix="$out" \
      --build=x86_64-unknown-linux-musl --host=x86_64-unknown-linux-gnu \
      --without-bash-malloc --disable-nls --disable-dependency-tracking
    make -j "$NIX_BUILD_CORES" SHELL=${shell}
    make -j "$NIX_BUILD_CORES" SHELL=${shell} install SHOBJ_STATUS=unsupported
    # Debug compilation directories include the M construction compiler's
    # intrinsic headers. Strip debug data before establishing runtime closure.
    ${scope.binutils}/bin/strip --strip-debug "$out/bin/bash"
    ln -s bash "$out/bin/sh"
    rm -f "$out/bin/bashbug"
    rm -rf "$out/share/man" "$out/share/info"
    mkdir -p "$out/share/licenses/bash"
    cp COPYING "$out/share/licenses/bash/"
  '';
  gnu-binutils = run "tvp-bootstrap-gnu-binutils-2.42" ''
    tar xf ${binutilsSrc}
    mkdir build
    cd build
    ${shell} ../binutils-2.42/configure --prefix="$out" \
      --build=x86_64-unknown-linux-musl --host=x86_64-unknown-linux-gnu \
      --target=x86_64-unknown-linux-gnu --disable-nls --disable-werror \
      --disable-gprofng --disable-gold --disable-multilib --disable-shared \
      --enable-static --without-zstd --without-debuginfod --without-isl
    make -j "$NIX_BUILD_CORES" SHELL=${shell} MAKEINFO=true
    make -j "$NIX_BUILD_CORES" SHELL=${shell} MAKEINFO=true install-strip
    find "$out/bin" -type f -exec ${scope.binutils}/bin/strip --strip-debug '{}' +
    rm -rf "$out/share/man" "$out/share/info"
    mkdir -p "$out/share/licenses/binutils"
    cp ../binutils-2.42/COPYING* "$out/share/licenses/binutils/"
  '';
}
