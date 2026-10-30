#!@bash@
set -e
# NIX_* flags are whitespace-separated flag lists, as in stdenv's native
# compiler protocol. User arguments remain an array, including response files.
compile_flags=()
read -r -d '' -a compile_flags <<< "${NIX_CFLAGS_COMPILE-}" || true
# Ordinary argv needs no helper or temporary file. For response files, capture
# expansion explicitly so a failed helper cannot hide in process substitution.
expand_args() {
    local arg
    expanded_args=("$@")
    for arg in "$@"; do
        [[ "$arg" = @?* ]] || continue
        expanded_file=$(@coreutils@/bin/mktemp)
        trap '@coreutils@/bin/rm -f "$expanded_file"' EXIT
        if ! @responseExpander@/bin/expand-response-params "$@" > "$expanded_file"; then
            exit 1
        fi
        mapfile -d '' -t expanded_args < "$expanded_file"
        @coreutils@/bin/rm -f "$expanded_file"
        trap - EXIT
        return 0
    done
}
link=true
static=false
shared=false
relocatable=false
optimized=false
scan_flags() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            -c|-E|-S|-M|-MM|-fsyntax-only) link=false ;;
            -static|-static-pie) static=true ;;
            -shared) shared=true ;;
            -r|-Wl,-r|-Wl,--relocatable) relocatable=true ;;
            -O|-Os|-Og|-Oz|-Ofast) optimized=true ;;
            -O[0-9]*)
                if [[ "$arg" =~ ^-O0+$ ]]; then optimized=false
                elif [[ "$arg" =~ ^-O[0-9]+$ ]]; then optimized=true; fi ;;
        esac
    done
}
expand_args "${compile_flags[@]}" "$@"
scan_flags "${expanded_args[@]}"
[[ @program@ != cpp ]] || link=false
# Link-only flags affect classification only when they will reach GCC. Keep
# requested flags even if they turn this into a relocatable or compile-only job.
link_flags=()
if $link; then
    read -r -d '' -a link_flags <<< "${NIX_CFLAGS_LINK-}" || true
    expand_args "${link_flags[@]}"
    scan_flags "${expanded_args[@]}"
fi
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
if $link && ! $relocatable; then
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
