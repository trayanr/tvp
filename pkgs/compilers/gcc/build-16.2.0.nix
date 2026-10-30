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
      "python3"
    ]
  );
  libcFlags = "-B${glibc}/lib/ -isystem ${lib.getDev glibc}/include -L${glibc}/lib -Wl,-dynamic-linker,${glibc}/${(platforms.forStdenv stdenv).dynamicLinker} -Wl,-rpath,${glibc}/lib";
in
assert bootstrap;
compiler.overrideAttrs (old: {
  outputs = [
    "out"
    "validation"
  ];
  nativeBuildInputs = old.nativeBuildInputs ++ [
    dejagnu
    python3
  ];
  postBuild = ''
    mkdir -p "$validation"
    test -f compare
    test ! -f stage2-lean
    test ! -f .bad_compare
    make -B compare 2>&1 | tee "$validation/bootstrap-compare.log"
    grep -Fx 'Comparison successful.' "$validation/bootstrap-compare.log"
    cp stage_final "$validation/stage_final"
    cp config.log "$validation/config.log"
    find stage2-gcc -name '*.o' | sort > "$validation/stage2-objects.txt"
    test -s "$validation/stage2-objects.txt"
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    # Supply only the explicit native libc layout. Test directives retain their
    # own optimisation/language options and unmodified expected diagnostics.
    mkdir -p boards
    cat > boards/tvp.exp <<'BOARD'
    load_generic_config "unix"
    set_board_info cflags "${libcFlags}"
    set_board_info ldflags "${libcFlags}"
    BOARD
    cat > site-tvp.exp <<SITE
    lappend boards_dir "$PWD/boards"
    SITE
    export DEJAGNU="$PWD/site-tvp.exp"
    export CONFIG_SHELL=${stdenv.shell}
    export SHELL=${stdenv.shell}
    targets=(check-gcc check-target-libstdc++-v3 check-target-libgomp
      check-target-libatomic check-target-libitm check-target-libquadmath
      check-target-libsanitizer)
    printf '%s\n' "make -k ''${targets[*]} RUNTESTFLAGS=--target_board=tvp" > "$validation/invocation.txt"
    result=0
    make -k "''${makeFlagsArray[@]}" "''${targets[@]}" \
      'RUNTESTFLAGS=--target_board=tvp' > "$validation/make-check.log" 2>&1 || result=$?
    printf '%s\n' "$result" > "$validation/make-check.exit"
    # Keep failures as data. The separate upstream test gates on the actual
    # DejaGNU records, never on make's exit status alone.
    find . -type f \( -name '*.sum' -o -name '*.log' \) -exec cp --parents {} "$validation" \;
    ${python3}/bin/python3 ${./tests/summarise-upstream.py} "$validation"
    runHook postCheck
  '';
})
