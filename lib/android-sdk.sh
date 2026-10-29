#!@bash@
set -eu
export PATH='@runtimePath@':$PATH
source '@helper@'
prepareWritableSdk '@sdk@' "${XDG_CACHE_HOME:-${NIX_BUILD_TOP:-$HOME/.cache}}/tvp/android" '@identity@'
