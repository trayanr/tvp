# Sourced into the generated standalone runner, never into a conditional term.
if (( $# != 1 )); then
    printf 'usage: runner PREPARED_SOURCE_ROOT\n' >&2
    exit 64
fi
cd -- "$1"
readonly TVP_SOURCE_ROOT="$PWD"
TVP_CURRENT=
TVP_CANCEL=
TVP_FINISHING=0
# Job control gives each launched job a process group owned by this runner.
# The child disables job control so ordinary descendants stay in that group.
set -m

# Logging is best effort. A bad descriptor or SIGPIPE must not change status.
tvp_log() (
    trap '' PIPE
    local event=$1
    if [[ ( $event == completion || $event == failure ) && -n $TVP_CANCEL ]]; then
        event=cancellation
    fi
    printf '\n@tvp-step {"event":"%s","name":"%s","status":%s}\n' "$event" "$2" "$3" >&2
)
tvp_phase() (
    trap '' PIPE
    if [[ ${NIX_LOG_FD-} =~ ^[0-9]+$ ]]; then
        { printf '@nix {"action":"setPhase","phase":"%s"}\n' "$1" >&"$NIX_LOG_FD"; } 2>/dev/null
    fi
)
tvp_reraise_cancel() {
    if [[ -n $TVP_CANCEL ]]; then
        trap - "$TVP_CANCEL"
        kill -s "$TVP_CANCEL" "$$"
        # Fallback if the shell has not yet delivered its own signal.
        case $TVP_CANCEL in
            TERM) exit 143;;
            INT) exit 130;;
            HUP) exit 129;;
        esac
    fi
}
tvp_signal() {
    # First observed external cancellation wins. No inference from wait status.
    if [[ -z $TVP_CANCEL ]]; then TVP_CANCEL=$1; fi
    if [[ -n $TVP_CURRENT ]]; then
        kill -s "$TVP_CANCEL" -- "-$TVP_CURRENT" 2>/dev/null || :
    elif (( TVP_FINISHING )); then
        tvp_reraise_cancel
    fi
}
trap 'tvp_signal TERM' TERM
trap 'tvp_signal INT' INT
trap 'tvp_signal HUP' HUP

tvp_cleanup() {
    local attempt
    # Allow a cooperative ordinary child tree time to exit and reap first.
    for ((attempt=0; attempt<20; attempt++)); do
        if ! kill -0 -- "-$TVP_CURRENT" 2>/dev/null; then return; fi
        sleep 0.05
    done
    kill -s TERM -- "-$TVP_CURRENT" 2>/dev/null || :
    for ((attempt=0; attempt<20; attempt++)); do
        if ! kill -0 -- "-$TVP_CURRENT" 2>/dev/null; then return; fi
        sleep 0.05
    done
    kill -s KILL -- "-$TVP_CURRENT" 2>/dev/null || :
}

tvp_step() {
    local name=$1 script=$2 status
    tvp_reraise_cancel
    tvp_log start "$name" null || :
    tvp_phase "$name" || :
    # Explicit environment boundary: no ambient functions, options, phase hooks,
    # search paths or previous step variables. Only build locations and the Nix
    # core budget cross into the fresh base environment.
    "$TVP_ENV" -i HOME="${HOME:-/homeless-shelter}" \
        TMPDIR="${TMPDIR:-/tmp}" NIX_BUILD_TOP="${NIX_BUILD_TOP:-$TVP_SOURCE_ROOT}" \
        NIX_BUILD_CORES="${NIX_BUILD_CORES:-1}" \
        out="${out:-$TVP_SOURCE_ROOT/result}" \
        "$TVP_BASH" --noprofile --norc "$script" "$TVP_SOURCE_ROOT" &
    TVP_CURRENT=$!
    if [[ -n $TVP_CANCEL ]]; then tvp_signal "$TVP_CANCEL"; fi
    # Only wait has errexit disabled; the step script is a fresh top-level Bash.
    set +e
    wait "$TVP_CURRENT"
    status=$?
    set -e
    # Cancellation can also arrive while residual descendants are cleaned up.
    tvp_cleanup
    if [[ -n $TVP_CANCEL ]]; then
        # An interrupted wait may precede actual child termination. Reap it.
        set +e
        wait "$TVP_CURRENT"
        set -e
        tvp_log cancellation "$name" "$status" || :
        TVP_CURRENT=
        tvp_reraise_cancel
    fi
    TVP_CURRENT=
    if (( status == 0 )); then
        tvp_log completion "$name" "$status" || :
    else
        tvp_log failure "$name" "$status" || :
        TVP_FINISHING=1
        tvp_reraise_cancel
        exit "$status"
    fi
    tvp_reraise_cancel
}
