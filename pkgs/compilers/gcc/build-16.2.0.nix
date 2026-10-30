# GCC 16 keeps the native C/C++ bootstrap procedure. Retain its comparison and
# run the configured languages' upstream suites before discarding the build tree.
{
  lib,
  stdenv,
  platforms,
  fetchurl,
  binutils,
  gmp,
  mpfr,
  mpc,
  isl,
  zlib,
  zstd,
  libxcrypt,
  perl,
  glibc,
  texinfo,
  which,
  dejagnu,
  flock,
  graphviz,
  fontsConf,
  python3,
  version,
  sha256,
  patches ? [ ],
  bootstrap ? true,
  hardeningDisable ? [ ],
  mkTests,
}@args:
let
  compiler = import ./build-13.3.nix (
    removeAttrs args [
      "dejagnu"
      "flock"
      "graphviz"
      "fontsConf"
      "python3"
    ]
  );
  libcFlags = "-B${glibc}/lib/ -idirafter ${lib.getDev glibc}/include -L${glibc}/lib -Wl,-dynamic-linker,${glibc}/${(platforms.forStdenv stdenv).dynamicLinker} -Wl,-rpath,${glibc}/lib";
in
assert bootstrap;
compiler.overrideAttrs (old: {
  outputs = [
    "out"
    "validation"
  ];
  nativeBuildInputs = old.nativeBuildInputs ++ [
    dejagnu
    (lib.getBin flock)
    (lib.getBin graphviz)
    python3
  ];
  postBuild = ''
    mkdir -p "$validation"
    test -f compare
    test ! -f stage2-lean
    test ! -f .bad_compare
    # Invalidate only the comparison stamp, not all generated makefiles.
    rm compare
    make compare 2>&1 | tee "$validation/bootstrap-compare.log"
    grep -Fx 'Comparison successful.' "$validation/bootstrap-compare.log"
    cp stage_final "$validation/stage_final"
    cp config.log "$validation/config.log"
    find stage2-gcc -name '*.o' | sort > "$validation/stage2-objects.txt"
    test -s "$validation/stage2-objects.txt"
    # compare stages the compiler directories; restore them once before the
    # parallel check targets can each try to start stage 3.
    make stage3-start 2>&1 | tee "$validation/stage3-start.log"
  '';
  doCheck = true;
  enableParallelChecking = true;
  checkTarget = [
    "check-gcc"
    "check-target-libstdc++-v3"
    "check-target-libgomp"
    "check-target-libatomic"
    "check-target-libitm"
    "check-target-libquadmath"
    "check-target-libsanitizer"
  ];
  checkFlags = [
    "-k"
    "RUNTESTFLAGS=--target_board=tvp"
  ];
  checkPhase = ''
    # Supply only the explicit native libc layout. Test directives retain their
    # own optimisation/language options and unmodified expected diagnostics.
    mkdir -p boards
    cat > boards/tvp.exp <<'BOARD'
    load_base_board_description "unix"
    unset_board_info isremote
    set_board_info isremote 0
    # GCC selectors concatenate these strings with per-test options.
    set_board_info cflags " ${libcFlags} "
    set_board_info ldflags " ${libcFlags} "
    BOARD
    cat > site-tvp.exp <<SITE
    lappend boards_dir "$PWD/boards"
    # Host-side test generators use the unchanged wrapped build compiler.
    set HOSTCC "${stdenv.cc}/bin/gcc"
    set HOSTCXX "${stdenv.cc}/bin/g++"
    SITE
    export DEJAGNU="$PWD/site-tvp.exp"
    export CONFIG_SHELL=${stdenv.shell}
    export SHELL=${stdenv.shell}
    export FONTCONFIG_FILE=${fontsConf}
    export XDG_CACHE_HOME="$PWD/.cache"
    mkdir -p "$XDG_CACHE_HOME"
    # Upstream stacktrace tests need caller DWARF. Keep the production runtime
    # flags and optimisation, adding debug information only for test programs.
    for flag in "''${makeFlagsArray[@]}"; do
      case "$flag" in
        CXXFLAGS_FOR_TARGET=*) checkFlagsArray+=("$flag -g") ;;
      esac
    done
    printf '%s\n' "FONTCONFIG_FILE=$FONTCONFIG_FILE" \
      "XDG_CACHE_HOME=$XDG_CACHE_HOME" "HOSTCC=${stdenv.cc}/bin/gcc" \
      "HOSTCXX=${stdenv.cc}/bin/g++" "NIX_BUILD_CORES=$NIX_BUILD_CORES" \
      > "$validation/test-environment.txt"
    # Invoke stdenv's check function, inheriting its parallelism from the
    # configured NIX_BUILD_CORES exactly as in the normal build phase.
    declare -f checkPhase > "$validation/check-procedure.sh"
    set +e
    ( set -e; checkPhase ) > "$validation/make-check.log" 2>&1
    result=$?
    set -e
    head -n 1 "$validation/make-check.log" > "$validation/invocation.txt"
    printf '%s\n' "$result" > "$validation/make-check.exit"
    # Keep failures as data. The separate upstream test gates on the actual
    # DejaGNU records, never on make's exit status alone.
    find . -type f \( -name '*.sum' -o -name '*.log' \) -exec cp --parents {} "$validation" \;
    ${python3}/bin/python3 ${./tests/summarise-upstream.py} "$validation"
  '';
})
