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
: "${NIX_HARDENING_ENABLE=bindnow fortify format pic relro stackprotector strictoverflow}"
export NIX_HARDENING_ENABLE
