#!@bash@
set -e
if [[ ${TVP_CC_LINK_FLAGS_SET-} = 1 ]]; then
    exec @binutils@/bin/@linker@ "$@"
fi
relocatable=false
static=false
for arg in "$@"; do
    case "$arg" in
        -r|--relocatable) relocatable=true ;;
        -static|--static) static=true ;;
    esac
done
flags=()
if ! $relocatable; then
    read -r -a flags <<< "${NIX_LDFLAGS-}"
    flags+=(-L@libc@/lib)
    if ! $static; then
        flags+=(-dynamic-linker @libc@/@dynamicLinker@ -rpath @libc@/lib)
    fi
    for flag in ${NIX_HARDENING_ENABLE-bindnow fortify format pic relro stackprotector strictoverflow}; do
        case "$flag" in
            bindnow) flags+=(-z now) ;;
            relro) flags+=(-z relro) ;;
        esac
    done
fi
exec @binutils@/bin/@linker@ "$@" "${flags[@]}"
