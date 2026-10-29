# The v2 base prunes link-time search paths. Libraries opened by name through
# dlopen must be declared in runtimeLibraryPaths; those directories are restored
# after patchelf has identified the libraries required by DT_NEEDED.
fixupOutputHooks+=(tvpShrinkRpaths)

tvpShrinkRpaths() {
    if [[ -n "${dontShrinkRpaths-}" || ! -e "$prefix" ]]; then return; fi
    local binary before after path
    local -a preserve
    concatTo preserve runtimeLibraryPaths
    for path in "${preserve[@]}"; do
        if [[ "$path" != /nix/store/* || ! -d "$path" ]]; then
            echo "runtimeLibraryPaths must name existing store directories: $path" >&2
            return 1
        fi
    done
    while IFS= read -r -d '' binary; do
        if ! isELF "$binary"; then continue; fi
        # Static executables have no dynamic section or RPATH to edit.
        if ! before=$(patchelf --print-rpath "$binary" 2>/dev/null); then continue; fi
        patchelf --shrink-rpath "$binary"
        after=$(patchelf --print-rpath "$binary")
        for path in "${preserve[@]}"; do
            case ":$after:" in *":$path:"*) ;; *) after="${after:+$after:}$path" ;; esac
        done
        if [[ "$after" != "$(patchelf --print-rpath "$binary")" ]]; then
            patchelf --set-rpath "$after" "$binary"
        fi
    done < <(find "$prefix" -type f -print0)
}
