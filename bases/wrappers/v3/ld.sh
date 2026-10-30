#!@bash@
set -e
if [[ ${TVP_CC_LINK_FLAGS_SET-} = 1 ]]; then
    exec @binutils@/bin/@linker@ "$@"
fi
flags=()
read -r -d '' -a flags <<< "${NIX_LDFLAGS-}" || true
expanded_args=("$@" "${flags[@]}")
for arg in "${expanded_args[@]}"; do
    [[ "$arg" = @?* ]] || continue
    expanded_file=$(@coreutils@/bin/mktemp)
    trap '@coreutils@/bin/rm -f "$expanded_file"' EXIT
    if ! @responseExpander@/bin/expand-response-params "${expanded_args[@]}" > "$expanded_file"; then
        exit 1
    fi
    mapfile -d '' -t expanded_args < "$expanded_file"
    @coreutils@/bin/rm -f "$expanded_file"
    trap - EXIT
    break
done
relocatable=false
static=false
for arg in "${expanded_args[@]}"; do
    case "$arg" in
        -r|--relocatable) relocatable=true ;;
        -static|--static) static=true ;;
    esac
done
flags=()
if ! $relocatable; then
    read -r -d '' -a flags <<< "${NIX_LDFLAGS-}" || true
    flags+=(-L@libc@/lib)
    if ! $static; then
        flags+=(-dynamic-linker @libc@/@dynamicLinker@ -rpath @libc@/lib)
    fi
    if [[ ${NIX_SET_BUILD_ID-} = 1 ]]; then
        flags+=("--build-id=${NIX_BUILD_ID_STYLE:-sha1}")
    fi
    for flag in ${NIX_HARDENING_ENABLE-bindnow fortify format pic relro stackprotector strictoverflow}; do
        case "$flag" in
            bindnow) flags+=(-z now) ;;
            relro) flags+=(-z relro) ;;
        esac
    done
fi
exec @binutils@/bin/@linker@ "$@" "${flags[@]}"
