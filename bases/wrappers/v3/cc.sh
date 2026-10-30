#!@bash@
set -e
# NIX_* flags are whitespace-separated flag lists, as in stdenv's native
# compiler protocol. User arguments remain an array, including response files.
compile_flags=()
read -r -d '' -a compile_flags <<< "${NIX_CFLAGS_COMPILE-}" || true
# Classify exactly the user flag order passed to GCC, including response files.
# Capture in a file so a failed helper cannot be hidden by process substitution.
expanded_file=$(@coreutils@/bin/mktemp)
trap '@coreutils@/bin/rm -f "$expanded_file"' EXIT
classification_flags=()
read -r -d '' -a classification_flags <<< "${NIX_CFLAGS_LINK-}" || true
if ! @responseExpander@/bin/expand-response-params "${compile_flags[@]}" "$@" "${classification_flags[@]}" > "$expanded_file"; then
    exit 1
fi
mapfile -d '' -t expanded_args < "$expanded_file"
@coreutils@/bin/rm -f "$expanded_file"
trap - EXIT
link=true
static=false
shared=false
relocatable=false
optimized=false
for arg in "${expanded_args[@]}"; do
    case "$arg" in
        -c|-E|-S|-M|-MM|-fsyntax-only) link=false ;;
        -static|-static-pie) static=true ;;
        -shared) shared=true ;;
        -r|-Wl,-r|-Wl,--relocatable) relocatable=true ;;
        -O|-O[1-9]*|-Os|-Og|-Oz|-Ofast) optimized=true ;;
        -O0) optimized=false ;;
    esac
done
[[ @program@ != cpp ]] || link=false
hardening=()
for flag in ${NIX_HARDENING_ENABLE-bindnow fortify format pic relro stackprotector strictoverflow}; do
    case "$flag" in
        fortify) if $optimized; then hardening+=(-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2); fi ;;
        fortify3) if $optimized; then hardening+=(-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3); fi ;;
        format) hardening+=(-Wformat -Wformat-security -Werror=format-security) ;;
        pic) hardening+=(-fPIC) ;;
        pie)
            if ! $shared && ! $relocatable && ! $static; then
                hardening+=(-fPIE)
                if $link; then hardening+=(-pie); fi
            fi ;;
        stackprotector) hardening+=(-fstack-protector-strong) ;;
        strictoverflow) hardening+=(-fno-strict-overflow) ;;
        zerocallusedregs) hardening+=(-fzero-call-used-regs=used-gpr) ;;
    esac
done
# Apply flags at the driver too: a caller may select raw binutils with -B.
# The marker prevents the normal linker wrapper from adding them a second time.
link_flags=()
if $link && ! $relocatable; then
    read -r -d '' -a link_flags <<< "${NIX_CFLAGS_LINK-}" || true
    link_flags+=(-L@libc@/lib -L@gcc@/lib)
    nix_ldflags=()
    read -r -d '' -a nix_ldflags <<< "${NIX_LDFLAGS-}" || true
    for flag in "${nix_ldflags[@]}"; do
        link_flags+=("-Wl,$flag")
    done
    if ! $static; then
        link_flags+=(-Wl,-dynamic-linker,@libc@/@dynamicLinker@ -Wl,-rpath,@libc@/lib)
    fi
    for flag in ${NIX_HARDENING_ENABLE-bindnow fortify format pic relro stackprotector strictoverflow}; do
        case "$flag" in
            bindnow) link_flags+=(-Wl,-z,now) ;;
            relro) link_flags+=(-Wl,-z,relro) ;;
        esac
    done
    if ! $static && { @cRuntime@ || [[ @program@ = g++ ]]; }; then
        link_flags+=(-Wl,-rpath,@gcc@/lib)
    fi
    if [[ ${NIX_SET_BUILD_ID-} = 1 ]]; then
        link_flags+=("-Wl,--build-id=${NIX_BUILD_ID_STYLE:-sha1}")
    fi
    export TVP_CC_LINK_FLAGS_SET=1
fi
exec @gcc@/bin/@program@ "${hardening[@]}" "${compile_flags[@]}" \
    "$@" -B@bintools@/bin/ -B@libc@/lib/ -idirafter @libc@/include \
    "${link_flags[@]}"
