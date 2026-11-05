#!@bash@
set -euo pipefail
export PATH=@tools@
export SHELL=@bash@ CONFIG_SHELL=@bash@
fail() { printf 'TVP GNU environment: %s\n' "$*" >&2; exit 64; }
[[ -z ${NIX_HARDENING_ENABLE:-} ]] || fail 'hardening requests are unsupported by this checkpoint'
# The shared encoder writes whitespace-free words separated by ASCII spaces.
# read does no expansion, unquoting, globbing or command substitution.
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
for word in "${ldwords[@]}"; do linker+=(-Xlinker "$word"); done
protocol=0
(( ${#compile[@]} + ${#link[@]} + ${#linker[@]} == 0 )) || protocol=1
# Inspect GCC response syntax only to classify the invocation; forward the
# original argv to GCC. Quotes and backslashes are data, never shell code.
# Quoting logic adapted from GCC16 libiberty/argv.c buildargv.
# Copyright (C) 1992-2026 Free Software Foundation, Inc.; LGPL-2.0-or-later.
# See COPYING.LIBIBERTY. The Bash adapter and protocol are TVP additions.
expanded=()
expand() {
    local depth=$1 arg file text ch token quote escaped started i
    shift
    (( depth < 64 )) || fail 'response nesting exceeds checkpoint limit'
    for arg in "$@"; do
        if [[ $arg != @* || ! -r ${arg:1} ]]; then
            if [[ $arg == @* && $protocol == 1 ]]; then fail 'unreadable response file with environment flags'; fi
            expanded+=("$arg")
            continue
        fi
        file=${arg:1}
        # read -d '' preserves trailing newlines; GCC response files are text.
        text=''
        IFS= read -r -d '' text < "$file" || :
        local -a tokens=()
        token='' quote='' escaped=0 started=0
        for (( i=0; i<${#text}; i++ )); do
            ch=${text:i:1}
            if (( escaped )); then
                [[ $ch == $'\n' ]] || token+=$ch
                escaped=0; started=1
            elif [[ $ch == \\ && $quote != "'" ]] && { [[ $quote != \" ]] || [[ ${text:i+1:1} == [$'$`"\\\n'] ]]; }; then
                escaped=1; started=1
            elif [[ -n $quote ]]; then
                if [[ $ch == "$quote" ]]; then quote=''; else token+=$ch; fi
            elif [[ $ch == \" || $ch == "'" ]]; then quote=$ch; started=1
            elif [[ $ch == [$' \t\n\r\v\f'] ]]; then
                if (( started )); then tokens+=("$token"); token=''; started=0; fi
            else token+=$ch; started=1
            fi
        done
        if (( started )); then tokens+=("$token"); fi
        expand "$((depth + 1))" "${tokens[@]}"
    done
}
expand 0 "$@"
direct=("${expanded[@]}")
expanded=()
expand 0 "${compile[@]}" "$@"
takes_operand() {
    case $1 in
        -o|-x|-I|-isystem|-iquote|-idirafter|-include|-imacros|-iprefix|-iwithprefix|-iwithprefixbefore|-isysroot|--sysroot|-L|-B|-Xlinker|-Xassembler|-Xpreprocessor|-MF|-MT|-MQ|-aux-info|-dumpbase|-dumpdir|-dumpbase-ext) return 0;;
        *) return 1;;
    esac
}
mode=link operand=0 query=0
for arg in "${expanded[@]}"; do
    if (( operand )); then operand=0; continue; fi
    if takes_operand "$arg"; then operand=1; continue; fi
    case $arg in
        -static-pie) fail 'static PIE is unsupported by this reduced GNU checkpoint';;
        -m32|-mx32|-mmusl|-mbionic|-muclibc) fail 'unsupported GNU checkpoint ABI mode';;
        -c|--compile|-S|--assemble|-E|--preprocess|-M|-MM|-fsyntax-only) mode=compile;;
        --version|--help*|--target-help|-dump*|-print*|--print-*|--dump*) query=1;;
        -*) ;;
        *) ;;
    esac
done
if (( query )) || [[ ${#direct[@]} == 1 && ${direct[0]} == -v ]]; then mode=query; fi
program=${0##*/}
program=${program#x86_64-unknown-linux-gnu-}
case $program in cc|gcc) program=gcc;; c++|g++) program=g++;; cpp) [[ $mode == query ]] || mode=compile;; esac
if [[ $mode == link ]]; then
    expanded=()
    expand 0 "${link[@]}"
    operand=0
    for arg in "${expanded[@]}"; do
        if (( operand )); then operand=0; continue; fi
        if takes_operand "$arg"; then operand=1; continue; fi
        case $arg in
            -static-pie) fail 'static PIE is unsupported by this reduced GNU checkpoint';;
            -m32|-mx32|-mmusl|-mbionic|-muclibc) fail 'unsupported GNU checkpoint ABI mode';;
            -c|--compile|-S|--assemble|-E|--preprocess|-M|-MM|-fsyntax-only|-print*|-dump*|--print-*|--dump*)
                fail 'mode-changing NIX_CFLAGS_LINK words are unsupported';;
        esac
    done
fi
case $mode in
    query) exec @compiler@/"$program" "$@";;
    compile) exec @compiler@/"$program" "${compile[@]}" "$@";;
    link) exec @compiler@/"$program" "${compile[@]}" "${link[@]}" "$@" "${linker[@]}";;
esac
