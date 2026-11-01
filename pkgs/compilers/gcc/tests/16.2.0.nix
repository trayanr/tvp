{
  pkgs,
  tvpLib,
  gcc,
  python3,
}:
let
  libc = gcc.tvp.deps.glibc;
  flags = "-B${libc}/lib/ -idirafter ${pkgs.lib.getDev libc}/include -L${libc}/lib -Wl,-dynamic-linker,${libc}/${gcc.platform.dynamicLinker} -Wl,-rpath,${gcc}/lib -Wl,-rpath,${libc}/lib";
in
{
  upstream-audit =
    pkgs.runCommand "gcc-${gcc.version}-upstream-audit"
      {
        nativeBuildInputs = [ python3 ];
        passthru = {
          package = gcc;
          testName = "upstream-audit";
        };
      }
      ''
        test "$(cat ${gcc.validation}/make-check.exit)" = 0
        mkdir -p "$out"
        # Audit exact reproduced outcomes; preserve raw FAIL/XPASS and report
        # strictUpstreamConformance=false instead of claiming a clean suite.
        python3 ${./audit-upstream.py} ${gcc.validation}/upstream.json \
          ${./upstream-known-16.2.0.json} ${gcc.version} ${pkgs.stdenv.hostPlatform.system} ${gcc.validation} \
          > "$out/audit.json"
        # libquadmath and libsanitizer ship no independent testsuite. Their
        # compiler-integrated cases remain in the GCC results; native runtime
        # consumers below exercise the installed libraries as well.
        cp ${gcc.validation}/upstream.json "$out/results.json"
        cp ${./upstream-known-16.2.0.json} "$out/classification.json"
        ln -s ${gcc.validation} "$out/raw"
      '';
}
// tvpLib.tests.mkSuite {
  inherit pkgs;
  package = gcc;
  tests = {
    runtime = {
      script = ''
        ${gcc}/bin/g++ ${flags} -std=c++20 -flto ${./fixtures/runtime-16.cc} -o runtime
        ${pkgs.binutils}/bin/readelf -l runtime | grep -F '${libc}/${gcc.platform.dynamicLinker}' >/dev/null
        ./runtime
      '';
      expected = "42\n${gcc}/lib/libstdc++.so.6";
    };
    graphite = {
      script = ''
        ${gcc}/bin/gcc ${flags} -O2 -fgraphite-identity -floop-nest-optimize -fdump-tree-graphite-details ${./fixtures/graphite.c} -o graphite
        grep -E 'number of SCoPs: [1-9]' *.graphite >/dev/null
        ./graphite
      '';
      expected = "3840";
    };
    sanitizers = {
      script = ''
        ${gcc}/bin/gcc ${flags} -fsanitize=address,undefined ${./fixtures/hello.c} -o instrumented
        LD_DEBUG=libs ./instrumented 2> loaded
        grep -F 'calling init: ${gcc}/lib/libasan.so' loaded >/dev/null
        grep -F 'calling init: ${gcc}/lib/libubsan.so' loaded >/dev/null
      '';
      expected = "42";
    };
    quadmath = {
      script = ''
        cat > quad.c <<'C'
        #include <quadmath.h>
        #include <stdio.h>
        int main(void) {
          char result[128];
          quadmath_snprintf(result, sizeof result, "%.0Qf", sqrtq(1764.0Q));
          puts(result);
          return 0;
        }
        C
        ${gcc}/bin/gcc ${flags} quad.c -lquadmath -o quad
        LD_DEBUG=libs ./quad 2> loaded
        grep -F 'calling init: ${gcc}/lib/libquadmath.so' loaded >/dev/null
      '';
      expected = "42";
    };
    actual-binutils = {
      extraInputs = [ pkgs.strace ];
      script = ''
        strace -f -e trace=execve -o selected ${gcc}/bin/gcc ${flags} ${./fixtures/hello.c} -o hello
        grep -F 'execve("${gcc.tvp.deps.binutils}/bin/as"' selected >/dev/null
        grep -F 'execve("${gcc.tvp.deps.binutils}/bin/ld"' selected >/dev/null
        ./hello
      '';
      expected = "42";
    };
  };
}
