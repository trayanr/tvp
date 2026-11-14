# Independent raw capture; statuses and upstream summaries are not rewritten.
{
  lib,
  s,
  flags,
  includes,
  links,
  shell,
  libc,
  sourceRoot,
}:
let
  # GCC 13 shares this capture helper and retains its single interpreter role.
  testPython = s.testPython or s.python;
in
''
  # Bind only the restored test helper; immutable production source stays exact.
  ${testPython}/bin/python3 -B ${../../../../lib/output-tools}/shebangs.py \
    "${sourceRoot}/source/libgomp/testsuite" \
    ${
      lib.escapeShellArg (
        builtins.toJSON {
          paths = [ "flock" ];
          names = [ "perl" ];
          interpreter = "${s.perl}/bin/perl";
          selfInterpreter = null;
        }
      )
    } ${../../../../lib/native-output}
  mkdir -p boards "$PWD/home" "$PWD/cache" "$validation"
  cat > boards/tvp.exp <<'BOARD'
  load_base_board_description "unix"
  unset_board_info isremote
  set_board_info isremote 0
  set_board_info cflags " -B${libc}/lib/ -idirafter ${libc}/include -L${libc}/lib -Wl,-rpath,${libc}/lib "
  set_board_info ldflags " -B${libc}/lib/ -L${libc}/lib -Wl,-rpath,${libc}/lib "
  BOARD
  cat > site-tvp.exp <<SITE
  lappend boards_dir "$PWD/boards"
  set HOSTCC "$CC"
  set HOSTCXX "$CXX"
  SITE
  export DEJAGNU="$PWD/site-tvp.exp" HOME="$PWD/home" XDG_CACHE_HOME="$PWD/cache"
  export FONTCONFIG_FILE=${s.fonts}/etc/fonts/fonts.conf PYTHONNOUSERSITE=1
  export PYTHONPATH="${sourceRoot}/source/gcc/testsuite''${PYTHONPATH:+:$PYTHONPATH}"
  printf '%s\n' "HOSTCC=$CC" "HOSTCXX=$CXX" "SHELL=$SHELL" "FONTCONFIG_FILE=$FONTCONFIG_FILE" > "$validation/test-environment.txt"
  # GCC clears MAKEOVERRIDES; preserve its default explicit forwarding list.
  printf '%s\n' 'EXTRA_GCC_FLAGS += "PLUGINCC=$(PLUGINCC)"' > tvp-plugin-host.mk
  check_status=0
  ${s.gnumake}/bin/make -f Makefile -f tvp-plugin-host.mk -j"$NIX_BUILD_CORES" -k SHELL=${shell} "''${flags[@]}" \
    "CXXFLAGS_FOR_TARGET=-O2 -g ${includes} ${links}" \
    PLUGINCC="$CXX" \
    RUNTESTFLAGS=--target_board=tvp \
    check-gcc check-target-libstdc++-v3 check-target-libgomp \
    check-target-libatomic check-target-libitm check-target-libquadmath \
    check-target-libsanitizer > "$validation/make-check.log" 2>&1 || check_status=$?
  head -n 1 "$validation/make-check.log" > "$validation/invocation.txt"
  printf '%s\n' "$check_status" > "$validation/make-check.exit"
  find . -type f \( -name '*.sum' -o -name '*.log' \) -exec cp --parents {} "$validation" \;
  ${testPython}/bin/python3 -B ${s.upstreamSummarizer} "$validation" > "$validation/outcomes.txt"
  # The qualification endpoint audits complete raw summaries and failures.
  # Retaining make's nonzero status is not an upstream pass assertion.
''
