#!@bash@
export NINJA="${NINJA:-@ninja@}"
export CMAKE="${CMAKE:-@cmake@}"
export PKG_CONFIG="${PKG_CONFIG:-@pkgConfig@}"
export SHELL="${SHELL:-@bash@}"
exec @python@ @out@/libexec/meson.pyz "$@"
