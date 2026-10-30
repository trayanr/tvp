# Validation companion only. Normal producers keep their original flags,
# static-library policy, recipe and identity. Run with static = true to include
# upstream's otherwise omitted static/renaming symbol tests.
{
  package,
  static ? false,
}:
package.overrideAttrs (old: {
  pname = "libxcrypt-upstream-validation";
  dontDisableStatic = static;
  checkPhase = ''
    runHook preCheck
    mkdir -p validation
    set -o pipefail
    make check 2>&1 | tee validation/check.log
    runHook postCheck
  '';
  installPhase = ''
    mkdir -p "$out"
    cp validation/check.log test-suite.log config.log config.h Makefile "$out/"
    cp libcrypt.map "$out/"
    find test -type f \( -name '*.log' -o -name '*.trs' \) -exec cp --parents {} "$out/" \;
  '';
  # These outputs contain logs and configuration, not installed libraries.
  dontFixup = true;
  passthru = (old.passthru or { }) // {
    inherit package;
    testName = if static then "upstream-static" else "upstream-shared";
  };
})
