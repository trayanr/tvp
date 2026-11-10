#!@bash@
set -euo pipefail
fail() { printf 'TVP Clang: %s\n' "$*" >&2; exit 64; }

# GNU response syntax is inspected for mode selection. The original argv is
# forwarded unchanged; no argument or environment value is evaluated as shell.
# The tokenizer follows the GNU adapter, adapted from GCC libiberty buildargv
# (FSF 1992-2026, LGPL-2.0-or-later; bootstrap/COPYING.LIBIBERTY).
expanded=()
expand() {
    local depth=$1 arg text ch token quote escaped started i
    shift
    (( depth < 64 )) || fail 'response-file nesting exceeds 64'
    for arg in "$@"; do
        if [[ $arg != @* ]]; then expanded+=("$arg"); continue; fi
        [[ -r ${arg:1} ]] || fail "unreadable response file: ${arg:1}"
        text=''
        IFS= read -r -d '' text < "${arg:1}" || :
        local -a tokens=()
        token='' quote='' escaped=0 started=0
        for (( i=0; i<${#text}; i++ )); do
            ch=${text:i:1}
            if (( escaped )); then
                token+=$ch; escaped=0; started=1
            elif [[ $ch == \\ && $quote != "'" ]]; then
                escaped=1; started=1
            elif [[ -n $quote ]]; then
                if [[ $ch == "$quote" ]]; then quote=''; else token+=$ch; fi
            elif [[ $ch == '"' || $ch == "'" ]]; then
                quote=$ch; started=1
            elif [[ $ch == [$' \t\n\r\v\f'] ]]; then
                if (( started )); then tokens+=("$token"); token=''; started=0; fi
            else
                token+=$ch; started=1
            fi
        done
        [[ -z $quote && $escaped == 0 ]] || fail 'unterminated response-file quoting'
        if (( started )); then tokens+=("$token"); fi
        expand "$((depth + 1))" "${tokens[@]}"
    done
}
takes_operand() {
    case $1 in
        -o|-x|-I|-F|-L|-B|-D|-U|-arch|-target|--target|--sysroot|-isysroot|\
        -isystem|-iquote|-idirafter|-include|-imacros|-iprefix|-iwithprefix|\
        -iwithprefixbefore|-iframework|-iframeworkwithsysroot|-resource-dir|\
        -Xlinker|-Xassembler|-Xpreprocessor|-Xclang|-Xanalyzer|-mllvm|\
        -MF|-MT|-MQ|-MJ|-aux-info|-dumpbase|-dumpbase-ext|-dumpdir) return 0;;
        *) return 1;;
    esac
}
mode=link static=false
classify() {
    local arg operand=0
    for arg in "${expanded[@]}"; do
        if (( operand )); then operand=0; continue; fi
        if takes_operand "$arg"; then operand=1; continue; fi
        case $arg in
            --rsp-quoting|--rsp-quoting=*) fail 'explicit response quoting overrides are unsupported (native GNU only)';;
            -c|--compile|-S|--assemble|-E|--preprocess|-M|-MM|-fsyntax-only) mode=compile;;
            -static|--static|-static-pie) static=true;;
            --version|--help*|-dumpmachine|-dumpversion|-print-*|--print-*) mode=query;;
        esac
    done
}
expand 0 "$@"
classify
if [[ $# == 1 && $1 == -v ]]; then mode=query; fi

compile=() link=() ldwords=() linker=()
for key in NIX_CFLAGS_COMPILE NIX_CFLAGS_LINK NIX_LDFLAGS; do
    value=${!key-}
    [[ $value != *[$'\t\n\r\v\f']* ]] || fail "$key: unsupported whitespace"
    [[ $key != NIX_LDFLAGS || $value != *,* ]] || fail "$key: commas are unsupported"
    words=()
    IFS=' ' read -r -a words <<< "$value"
    case $key in
        NIX_CFLAGS_COMPILE) compile=("${words[@]}");;
        NIX_CFLAGS_LINK) link=("${words[@]}");;
        NIX_LDFLAGS) ldwords=("${words[@]}");;
    esac
done

flags=(--gcc-install-dir=@gccInstallDir@ --sysroot=@emptyRoot@ -idirafter @libc@/include -B@libc@/lib/ -B@gccInstallDir@/ -B@gccRuntime@/lib/ -B@bintools@/bin/)
case "${0##*/}" in clang++*) flags+=(--driver-mode=g++);; esac

# Queries do not consume build-environment flags. Compile flags may themselves
# select compile-only operation; link-only channels may not change the mode.
if [[ $mode != query ]]; then
    expanded=()
    expand 0 "${compile[@]}" "$@"
    mode=link static=false
    classify
    [[ $mode != query ]] || fail 'query-changing compile environment flags'
    if [[ $mode == link ]]; then
        expanded=()
        expand 0 "${link[@]}"
        operand=0
        for arg in "${expanded[@]}"; do
            if (( operand )); then operand=0; continue; fi
            if takes_operand "$arg"; then operand=1; continue; fi
            case $arg in
                --rsp-quoting|--rsp-quoting=*) fail 'explicit response quoting overrides are unsupported (native GNU only)';;
                -c|--compile|-S|--assemble|-E|--preprocess|-M|-MM|-fsyntax-only|\
                --version|--help*|-dumpmachine|-dumpversion|-print-*|--print-*)
                    fail 'mode-changing NIX_CFLAGS_LINK words';;
                -static|--static|-static-pie) static=true;;
            esac
        done
        flags+=(-L@libc@/lib -L@cxxRuntime@/lib -L@gccRuntime@/lib)
        if ! $static; then
            flags+=(-Wl,-dynamic-linker,@loader@ -Wl,-rpath,@libc@/lib -Wl,-rpath,@cxxRuntime@/lib -Wl,-rpath,@gccRuntime@/lib)
        fi
        for word in "${ldwords[@]}"; do linker+=(-Xlinker "$word"); done
    fi
fi
case $mode in
    query) exec @clang@ "${flags[@]}" "$@";;
    compile) exec @clang@ "${flags[@]}" "${compile[@]}" "$@";;
    link) exec @clang@ "${flags[@]}" "${compile[@]}" "${link[@]}" "$@" "${linker[@]}";;
esac
