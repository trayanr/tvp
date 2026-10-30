# Supplemental upstream coverage with Python in the test environment only.
{ pkgs, isl }:
let
  lib = pkgs.lib;
  modern = lib.versionAtLeast isl.version "0.21";
  gmp = isl.tvp.deps.gmp;
  groups =
    [
      "isl_test"
      "codegen_test.sh"
      "pip_test.sh"
      "bound_test.sh"
      "isl_test_int"
      "flow_test.sh"
      "schedule_test.sh"
    ]
    ++ lib.optionals modern [
      "isl_test2"
      "isl_test_cpp"
      "isl_test_cpp_failed.sh"
      "isl_test_cpp17"
      "isl_test_cpp17-checked"
    ]
    ++ lib.optionals (lib.versionAtLeast isl.version "0.27") [
      "isl_test_cpp-checked"
      "isl_test_cpp-checked-conversion"
      "isl_test_python.py"
    ];
in
isl.stdenv.mkDerivation {
  name = "isl-${isl.version}-upstream-coverage";
  inherit (isl) src configureFlags;
  nativeBuildInputs = [
    isl.tvp.cc
    pkgs.python3
  ];
  buildInputs = [ gmp ];
  enableParallelBuilding = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    set -euo pipefail
    mkdir -p "$out"
    {
      make check
      for group in ${lib.concatStringsSep " " groups}; do
        result="$group"
        case "$group" in *.py) result="''${group%.py}" ;; esac
        grep -qx ':test-result: PASS' "$result.trs"
        echo "PASS upstream $group"
      done
      ${
        lib.optionalString (isl.version == "0.26") ''
          echo 'SKIP upstream C++11 checked/conversion and Python groups: ISL 0.26 gates these on the optional Clang interface generator'
        ''
      }
      ${
        lib.optionalString (!modern) ''
          echo 'SKIP upstream C++11/C++17: ISL 0.20 does not ship these test groups'
          echo 'SKIP upstream Python: ISL 0.20 requires the optional Clang interface generator; no generated bindings shipped'
        ''
      }
    } 2>&1 | tee "$out/log"
    runHook postCheck
  '';
  installPhase = ''
    cp config.log test-suite.log "$out/"
    mkdir "$out/results"
    cp *.trs *.log "$out/results/"
    cp include/isl/stdint.h "$out/"
    cp Makefile "$out/Makefile.configured"
  '';
  dontFixup = true;
  passthru = {
    package = isl;
    testName = "upstream-coverage";
  };
}
