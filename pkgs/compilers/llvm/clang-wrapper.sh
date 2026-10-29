#!@bash@
set -e
cxx=false
case "${0##*/}" in clang++*) cxx=true ;; esac
link=true
static=false
for arg in "$@"; do
    case "$arg" in
        -c|-S|-E|-M|-MM|-fsyntax-only) link=false ;;
        -static|--static) static=true ;;
    esac
done
# Keep host /usr paths out without rebasing glibc's absolute store linker
# scripts. libc must follow the C++ headers for their #include_next directives.
flags=(--gcc-install-dir=@gccInstallDir@ --sysroot=@emptyRoot@ -idirafter @libc@/include -B@libc@/lib/ -B@bintools@/bin)
if $cxx; then flags+=(--driver-mode=g++); fi
if $link; then
    flags+=(-L@libc@/lib -L@gcc@/lib)
    if ! $static; then
        flags+=(-Wl,-dynamic-linker,@libc@/@dynamicLinker@ -Wl,-rpath,@libc@/lib -Wl,-rpath,@gcc@/lib)
    fi
fi
exec @clang@ "${flags[@]}" "$@"
