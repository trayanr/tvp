unpackZip() {
    case "$1" in
        *.zip|*.ZIP) unzip -qq "$1" ;;
        *) return 1 ;;
    esac
}
unpackCmdHooks+=(unpackZip)
