# Sourced by SDK builders. Call only for directories containing host tools;
# Android target sysroots and target compiler runtimes must remain untouched.
patchHostTools() {
    local directory binary old_rpath
    for directory in "$@"; do
        while IFS= read -r -d '' binary; do
            if isELF "$binary"; then
                chmod u+w "$binary"
                if patchelf --print-interpreter "$binary" >/dev/null 2>&1; then
                    patchelf --set-interpreter "$hostDynamicLinker" "$binary"
                fi
                old_rpath=$(patchelf --print-rpath "$binary")
                patchelf --set-rpath "$old_rpath:$hostRuntimePaths" "$binary"
                patchelf --shrink-rpath "$binary"
            fi
        done < <(find "$directory" -maxdepth 1 -type f -print0)
    done
}
