{ pkgs, isl }:
let
  lib = pkgs.lib;
  modern = lib.versionAtLeast isl.version "0.21";
  gmp = isl.tvp.deps.gmp;
  logged =
    name: script:
    pkgs.runCommandWith
      {
        name = "isl-${isl.version}-${name}";
        stdenv = isl.stdenv;
        derivationArgs = {
          nativeBuildInputs = [
            isl.tvp.cc
            pkgs.patchelf
          ];
          buildInputs = [
            isl
            gmp
          ];
          passthru = {
            package = isl;
            testName = name;
          };
        };
      }
      ''
        set -euo pipefail
        mkdir -p "$out"
        {
          ${script}
        } 2>&1 | tee "$out/log"
      '';
  cpp =
    standard:
    logged "consumer-${standard}" (
      if modern then
        ''
          c++ -std=${standard} -Wall -Wextra -Werror ${./fixtures/consumer.cc} -lisl -lgmp -o consumer
          ./consumer
          echo 'PASS ${standard} matching generated C++ bindings'
        ''
      else
        ''
          test ! -e ${isl}/include/isl/cpp.h
          echo 'SKIP ${standard}: ISL 0.20 does not ship installed generated C++ bindings'
        ''
    );
in
{
  semantics = logged "semantics" ''
    cc -std=c99 -Wall -Wextra -Werror ${lib.optionalString modern "-DMODERN_API"} \
      ${./fixtures/semantics.c} -lisl -lgmp -o semantics
    ./semantics
  '';
  cpp11 = cpp "c++11";
  cpp17 = cpp "c++17";
  loaded-library = logged "loaded-library" (
    if isl.stdenv.hostPlatform.isLinux then
      ''
        cc -std=c99 -Wall -Wextra -Werror ${./fixtures/loaded.c} -lisl -lgmp -ldl -o loaded
        ./loaded ${isl}/lib/libisl.so ${lib.getLib gmp}/lib/libgmp.so ${lib.escapeShellArg isl.version}
        soname=$(patchelf --print-soname ${isl}/lib/libisl.so)
        test "$soname" = ${if modern then "libisl.so.23" else "libisl.so.19"}
        echo "PASS ELF SONAME $soname"
        test "$(patchelf --print-needed ${isl}/lib/libisl.so | grep -cx 'libgmp.so.10')" = 1
        echo 'PASS ISL needs libgmp.so.10'
      ''
    else
      ''
        echo 'SKIP loaded-library: ELF/dladdr assertions are Linux-specific'
      ''
  );
}
