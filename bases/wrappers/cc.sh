#!@bash@
set -e
# NIX_* flags are whitespace-separated flag lists, as in stdenv's native
# compiler protocol. User arguments remain an array, including response files.
compile_flags=()
read -r -a compile_flags <<< "${NIX_CFLAGS_COMPILE-}"
link=true
static=false
shared=false
relocatable=false
optimized=false
for arg in "$@"; do
    case "$arg" in
        -c|-E|-S|-M|-MM|-fsyntax-only) link=false ;;
        -static|-static-pie) static=true ;;
        -shared) shared=true ;;
        -r|-Wl,-r|-Wl,--relocatable) relocatable=true ;;
        -O[123sg]|-Ofast) optimized=true ;;
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
        pie) hardening+=(-fPIE); if $link && ! $shared && ! $static; then hardening+=(-pie); fi ;;
        stackprotector) hardening+=(-fstack-protector-strong) ;;
        strictoverflow) hardening+=(-fno-strict-overflow) ;;
        zerocallusedregs) hardening+=(-fzero-call-used-regs=used-gpr) ;;
    esac
done
# Apply flags at the driver too: a caller may select raw binutils with -B.
# The marker prevents the normal linker wrapper from adding them a second time.
link_flags=()
if $link && ! $relocatable; then
    read -r -a link_flags <<< "${NIX_CFLAGS_LINK-}"
    link_flags+=(-L@libc@/lib -L@gcc@/lib)
    nix_ldflags=()
    read -r -a nix_ldflags <<< "${NIX_LDFLAGS-}"
    for flag in "${nix_ldflags[@]}"; do
        link_flags+=("-Wl,$flag")
    done
    if ! $static; then
        link_flags+=(-Wl,-dynamic-linker,@libc@/lib/ld-linux-x86-64.so.2 -Wl,-rpath,@libc@/lib)
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
    export TVP_CC_LINK_FLAGS_SET=1
fi
exec @gcc@/bin/@program@ "${hardening[@]}" "${compile_flags[@]}" \
    "$@" -B@bintools@/bin/ -B@libc@/lib/ -idirafter @libc@/include \
    "${link_flags[@]}"
