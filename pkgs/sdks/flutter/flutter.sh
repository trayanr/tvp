#!@bash@
set -euo pipefail
export PATH="@runtimePath@:$PATH"
cache_root="${TVP_FLUTTER_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/tvp/flutter}"
source '@sdkHelper@'
cache=$(prepareWritableSdk '@sdk@' "$cache_root" "$(basename "$(dirname "$(dirname '@sdk@')")")")
export FLUTTER_ROOT="$cache"
export PUB_CACHE="${PUB_CACHE:-$cache/.pub-cache}"
export JAVA_HOME='@jdk@'
if test -z "${ANDROID_HOME:-}" || test "$ANDROID_HOME" = '@androidSdk@'; then
    ANDROID_HOME=$('@androidSdkTool@')
fi
export ANDROID_HOME
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export SSL_CERT_FILE="${SSL_CERT_FILE:-@certificates@}"
'@gradle@/bin/tvp-gradle-seed-wrapper'
exec "$cache/bin/flutter-internal" "$@"
