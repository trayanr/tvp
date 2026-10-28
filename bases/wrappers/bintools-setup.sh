tvpAddLibraries() {
    # Interpreters often have a lib/ containing modules rather than linker
    # inputs. Do not retain a native build tool through an unused RPATH.
    local library found=false shared=false
    for library in "$1"/lib/lib*.so* "$1"/lib/lib*.a; do
        if [ -f "$library" ]; then
            found=true
            case "$library" in *.so*) shared=true ;; esac
        fi
    done
    if $found; then
        export NIX_LDFLAGS="${NIX_LDFLAGS-} -L$1/lib"
        if $shared; then
            export NIX_LDFLAGS="${NIX_LDFLAGS-} -rpath $1/lib"
        fi
    fi
}
addEnvHooks "$targetOffset" tvpAddLibraries
export NIX_BINTOOLS=@out@
export AR=ar AS=as LD=ld NM=nm RANLIB=ranlib STRIP=strip
