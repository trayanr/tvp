#!@bash@
set -e
cxx=false
case "${0##*/}" in clang++*) cxx=true ;; esac
link=true
static=false
query=false
for arg in "$@"; do
    case "$arg" in
        -c|-S|-E|-M|-MM|-fsyntax-only) link=false ;;
        -static|--static|-static-pie) static=true ;;
        --version|-dump*|-print-*|--print-*) query=true ;;
    esac
done
flags=(--gcc-install-dir=@gccInstallDir@ --sysroot=@emptyRoot@ -idirafter @libc@/include -B@libc@/lib/ -B@bintools@/bin)
if $cxx; then flags+=(--driver-mode=g++); fi
# Owned environments contribute the same whitespace-free argument protocol as
# the GNU driver. Explicit command-line flags follow the defaults and win.
if ! $query; then
    read -r -a compile_flags <<< "${NIX_CFLAGS_COMPILE-}"
    flags+=("${compile_flags[@]}")
    if $link; then
        flags+=(-L@libc@/lib -L@gccRuntime@/lib -L@cxxRuntime@/lib)
        if ! $static; then
            flags+=(-Wl,-dynamic-linker,@loader@ -Wl,-rpath,@libc@/lib -Wl,-rpath,@gccRuntime@/lib -Wl,-rpath,@cxxRuntime@/lib)
        fi
        read -r -a link_flags <<< "${NIX_LDFLAGS-}"
        for flag in "${link_flags[@]}"; do flags+=("-Wl,$flag"); done
    fi
fi
exec @clang@ "${flags[@]}" "$@"
