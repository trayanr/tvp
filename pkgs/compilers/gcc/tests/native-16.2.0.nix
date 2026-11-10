# Ordinary raw GCC probes on the owned test constructor. All providers and
# rebound package paths come from the effective specification.
{ package }:
let
  gcc = package;
  spec = package.specification;
  libc = spec.glibc;
  flags = "-B${libc}/lib/ -idirafter ${libc}/include -L${libc}/lib -Wl,-dynamic-linker,${libc}/lib/ld-linux-x86-64.so.2 -Wl,-rpath,${gcc}/lib -Wl,-rpath,${libc}/lib";
  normalise = package.tvp.upstream.normalise;
in
assert
  map normalise [
    "href=\"gcc-2.95/\""
    "href=\"gcc-2.95.2.1/\""
    "href=\"gcc-16.2.0/\""
    "href=\"gcc-16.2.1-rc1/\""
    "href=\"snapshots/gcc-16.2.1/\""
  ] == [
    "2.95"
    "2.95.2.1"
    "16.2.0"
    null
    null
  ];
package.testContext.mkSuite {
  inherit package;
  tools = spec.environment.tools;
  # Tests name their own raw include/link flags. No consumer driver replaces gcc.
  tests = {
    version = {
      script = ''${gcc}/bin/gcc -dumpfullversion'';
      expected = gcc.version;
    };
    c = {
      script = ''${gcc}/bin/gcc ${flags} ${./fixtures/hello.c} -o hello; ./hello'';
      expected = "42";
    };
    cxx = {
      script = ''${gcc}/bin/g++ ${flags} ${./fixtures/hello.cc} -o hello; ./hello'';
      expected = "42";
    };
    lto = {
      script = ''${gcc}/bin/gcc ${flags} -flto ${./fixtures/hello.c} -o hello; ./hello'';
      expected = "42";
    };
    binutils = {
      script = ''
        test "$(${gcc}/bin/gcc -print-prog-name=as)" = "${spec.binutils}/bin/as"
        test "$(${gcc}/bin/gcc -print-prog-name=ld)" = "${spec.binutils}/bin/ld"
        printf ok
      '';
      expected = "ok";
    };
    tool-overrides = {
      script = ''
        mkdir tools
        for tool in as ld; do
          cat > tools/$tool <<'SHIM'
        #!${spec.bash}/bin/bash
        tool=''${0##*/}
        printf '%s\n' "$tool" >> "$TVP_TOOL_TEST_LOG"
        exec "$TVP_TOOL_REAL/$tool" "$@"
        SHIM
        done
        chmod +x tools/as tools/ld
        export TVP_TOOL_TEST_LOG="$PWD/selected-tools"
        export TVP_TOOL_REAL=${spec.binutils}/bin
        test "$(${gcc}/bin/gcc -B"$PWD/tools/" -print-prog-name=as)" = "$PWD/tools/as"
        test "$(${gcc}/bin/gcc -B"$PWD/tools/" -print-prog-name=ld)" = "$PWD/tools/ld"
        ${gcc}/bin/gcc -B"$PWD/tools/" ${flags} ${./fixtures/hello.c} -o hello
        grep -Fxq as selected-tools
        grep -Fxq ld selected-tools
        ./hello
      '';
      expected = "42";
    };
    runtime = {
      script = ''
        ${gcc}/bin/g++ ${flags} -std=c++20 -flto ${./fixtures/runtime-16.cc} -o runtime
        ${spec.binutils}/bin/readelf -l runtime | grep -F '${libc}/lib/ld-linux-x86-64.so.2' >/dev/null
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
      script = ''
        mkdir tools
        for tool in as ld; do
          cat > tools/$tool <<'SHIM'
        #!${spec.bash}/bin/bash
        tool=''${0##*/}
        printf '%s\n' "$tool" >> "$TVP_TOOL_TEST_LOG"
        exec "$TVP_TOOL_REAL/$tool" "$@"
        SHIM
        done
        chmod +x tools/as tools/ld
        export TVP_TOOL_TEST_LOG="$PWD/selected-tools"
        export TVP_TOOL_REAL=${spec.binutils}/bin
        export COMPILER_PATH="$PWD/tools"
        test "$(${gcc}/bin/gcc -print-prog-name=as)" = "$PWD/tools/as"
        test "$(${gcc}/bin/gcc -print-prog-name=ld)" = "$PWD/tools/ld"
        ${gcc}/bin/gcc ${flags} ${./fixtures/hello.c} -o hello
        grep -Fxq as selected-tools
        grep -Fxq ld selected-tools
        ./hello
      '';
      expected = "42";
    };
    upstream-audit = {
      script = ''
        test "$(cat ${gcc.validation}/make-check.exit)" = 0
        grep -Fx 'Comparison successful.' ${gcc.validation}/bootstrap-compare.log >/dev/null
        ${spec.python}/bin/python3 -B ${./audit-upstream.py} ${gcc.validation}/upstream.json \
          ${./upstream-known-16.2.0.json} ${spec.version} ${spec.base.platform.system} ${gcc.validation} > audit.json
        printf classified
      '';
      expected = "classified";
    };
    raw-libc-construction = {
      script = ''
        mkdir headers
        printf '#define VALUE 42\n' > headers/owned.h
        cat > libc-probe.c <<'C'
        #include <owned.h>
        extern void escape(void *);
        int probe(char *s) { char local[32]; __builtin_memcpy(local, s, sizeof local); escape(local); return local[VALUE % 32]; }
        C
        ${gcc}/bin/gcc -nostdinc -Iheaders -O2 -fstack-protector-strong -fPIE -c libc-probe.c -o libc-probe.o
        ${spec.binutils}/bin/nm -u libc-probe.o | grep -F __stack_chk_fail >/dev/null
        cat > startup.s <<'ASM'
        .global _start
        .text
        _start:
          mov $60, %rax
          xor %rdi, %rdi
          syscall
        .section .note.GNU-stack,"",@progbits
        ASM
        # Like public glibc, the caller supplies startup objects and suppresses
        # the compiler's target libc. No restricted-driver option filtering.
        ${gcc}/bin/gcc -B${spec.binutils}/bin/ -static-pie -nostdlib -Wl,-e,_start startup.s -o static-pie
        ${spec.binutils}/bin/readelf -h static-pie | grep -E 'Type:.*DYN' >/dev/null
        if ${spec.binutils}/bin/readelf -l static-pie | grep -q INTERP; then exit 1; fi
        ./static-pie
        printf raw-compatible
      '';
      expected = "raw-compatible";
    };
    tracker = {
      script = ''
        cat > index.html <<'HTML'
        <a href="gcc-2.95/">old</a>
        <a href="gcc-2.95.2.1/">old</a>
        <a href="gcc-16.2.0/">stable</a>
        <a href="gcc-16.2.0/">duplicate</a>
        <a href="gcc-16.2.1-rc1/">rc</a>
        <a href="gcc-16-20260401/">snapshot</a>
        <a href="snapshots/gcc-16.2.1/">nested</a>
        <a href="gcc-16..1/">junk</a>
        <a href="gcc-16.2.0.tar.xz">archive</a>
        HTML
        ${spec.python}/bin/python3 -B - <<'PYTHON'
        import re
        links = re.findall(r'${package.tvp.upstream.pattern}', open('index.html').read())
        versions = sorted(set(m.group(1) for link in links if (m := re.fullmatch(r'href="gcc-([0-9]+(?:\.[0-9]+)+)/"', link))))
        assert versions == ['16.2.0', '2.95', '2.95.2.1'], versions
        print('stable-index')
        PYTHON
      '';
      expected = "stable-index";
    };
  };
}
