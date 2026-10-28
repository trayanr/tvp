# aclocal must see the macros provided by named package inputs.
tvpAddAclocalFiles() {
    if [ -d "$1/share/aclocal" ]; then
        addToSearchPathWithCustomDelimiter : ACLOCAL_PATH "$1/share/aclocal"
    fi
}
addEnvHooks "$hostOffset" tvpAddAclocalFiles
