# Native-only compiler protocol. Propagation and dependency traversal belong to
# setup.sh; the compiler owns the include-path hook.
tvpAddIncludes() {
    if [ -d "$1/include" ]; then
        export NIX_CFLAGS_COMPILE="${NIX_CFLAGS_COMPILE-} -isystem $1/include"
    fi
}
addEnvHooks "$targetOffset" tvpAddIncludes
addToSearchPath _PATH @bintools@/bin
addToSearchPath _PATH @libcBin@/bin
export NIX_CC=@out@
export CC=cc CXX=c++
# Structured attributes provide an array, including an explicitly empty one.
# Environment variables must be scalars before export; assignment alone keeps
# Bash's array type. The default applies only when the value was absent.
tvpNormalizeHardening() {
    if [[ $(declare -p NIX_HARDENING_ENABLE 2>/dev/null) = "declare -a "* ]]; then
        local flags="${NIX_HARDENING_ENABLE[*]}"
        unset NIX_HARDENING_ENABLE
        NIX_HARDENING_ENABLE=$flags
    fi
}
tvpNormalizeHardening
unset -f tvpNormalizeHardening
: "${NIX_HARDENING_ENABLE=bindnow fortify format pic relro stackprotector strictoverflow}"
export NIX_HARDENING_ENABLE
