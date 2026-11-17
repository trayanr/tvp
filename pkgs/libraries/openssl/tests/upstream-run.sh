# Preserve the full native workload and its exit status.
set -eu
make=$1
shell=$2
perl=$3
version=$4
set --
case "$version" in
  0.9.6*|0.9.7*)
    set -- --eval='.NOTPARALLEL: build-shared'
    ;;
  0.9.8*)
    # Match the production dependency repair when reconstructing legacy tests.
    set -- --eval='libcrypto.a: build_crypto' --eval='libssl.a: build_ssl' --eval='build_engines: build_shared'
    ;;
esac
export HARNESS_JOBS="$NIX_BUILD_CORES"
exec "$make" -j"$NIX_BUILD_CORES" "SHELL=$shell" "PERL=$perl" "$@" test
