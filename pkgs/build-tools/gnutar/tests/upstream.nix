# Supplemental validation only. This builds upstream's own helpers and saves
# unmodified check/installcheck results, including failures, for adjudication.
# It is deliberately separate from the routine bounded suite.
{ package, helpers }:
package.overrideAttrs (old: {
  name = "gnutar-${package.version}-upstream-validation";
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ helpers;
  doCheck = false;
  dontFixup = true;
  installPhase = ''
    set -euo pipefail
    mkdir -p "$out"
    cp config.log config.h "$out/"
    make -C tests genfile checkseekhole ckmtime
    cp tests/genfile tests/checkseekhole tests/ckmtime "$out/"
    # No FULL_TEST: no downloads or unbounded external corpus.
    export TARTEST_SKIP_LARGE_FILES=1
    run_suite() {
      local name=$1
      shift
      local rc=0
      "$@" 2>&1 | tee "$out/$name.log" || rc=$?
      echo "$rc" > "$out/$name.status"
      cp tests/testsuite.log "$out/$name.testsuite.log"
      if test -d tests/testsuite.dir; then
        cp -r tests/testsuite.dir "$out/$name.testsuite.dir"
      fi
    }
    run_suite check make check
    run_suite installcheck make installcheck exec_prefix=${package}
  '';
})
