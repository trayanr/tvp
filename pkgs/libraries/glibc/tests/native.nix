# Full installed controls, staged only until the independently reviewed build.
{ package }:
let
  glibc = package;
  spec = package.specification;
  inherit (spec) gcc binutils;
  flags = "-B${binutils}/bin/ -B${glibc}/lib/ -isystem ${glibc}/include -L${glibc}/lib -Wl,-rpath-link,${glibc}/lib -Wl,-rpath-link,${gcc}/lib -Wl,-dynamic-linker,${glibc}/${glibc.platform.dynamicLinker} -Wl,-rpath,${glibc}/lib -Wl,-rpath,${gcc}/lib";
  clean = ''
    unset NIX_CFLAGS_COMPILE NIX_CFLAGS_LINK NIX_LDFLAGS
    unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH
  '';
  tools = glibc.mkTools { inherit (spec) base bash perl; };
in
glibc.testContext.mkSuite {
  inherit package;
  tools = [
    spec.coreutils
    gcc
    binutils
    spec.grep
    spec.gawk
    spec.sed
  ];
  tests = {
    version = {
      script = ''${glibc.bin}/bin/getconf GNU_LIBC_VERSION'';
      expected = "glibc ${glibc.version}";
    };
    runtime = {
      script =
        clean
        + ''
          ${gcc}/bin/gcc ${flags} ${./fixtures/runtime.c} -pthread -ldl -lm -o runtime
          ${binutils}/bin/readelf -l runtime | grep -F '${glibc}/${glibc.platform.dynamicLinker}' >&2
          ./runtime ${glibc.version}
        '';
      expected = "ok";
    };
    static = {
      script =
        clean
        + ''
          ${gcc}/bin/gcc ${flags} -static ${./fixtures/static.c} -o static
          test -z "$(${binutils}/bin/readelf -l static | grep INTERP)"
          ./static
        '';
      expected = "42";
    };
    tools = {
      script = ''
        printf hello | ${glibc.bin}/bin/iconv -f UTF-8 -t UTF-16LE | ${glibc.bin}/bin/iconv -f UTF-16LE -t UTF-8
        printf '\n'
      '';
      expected = "hello";
    };
    ldd = {
      script =
        clean
        + ''
          ${gcc}/bin/gcc ${flags} ${./fixtures/static.c} -o dynamic
          PATH=/no-tools ${tools}/bin/ldd ./dynamic | awk '/libc.so.6 =>/ { print $3 }'
        '';
      expected = "${glibc}/lib/libc.so.6";
    };
    static-pie = {
      script =
        clean
        + ''
          ${gcc}/bin/gcc ${flags} -static-pie ${./fixtures/static.c} -o static-pie
          ${binutils}/bin/readelf -h static-pie | grep -E 'Type:.*DYN' >&2
          test -z "$(${binutils}/bin/readelf -l static-pie | grep INTERP)"
          test -z "$(${binutils}/bin/readelf -d static-pie | grep NEEDED)"
          ./static-pie
        '';
      expected = "42";
    };
    locale-headers = {
      script =
        clean
        + ''
          ${gcc}/bin/gcc ${flags} ${./fixtures/locale-headers.c} -o locale-headers
          ./locale-headers
          LOCPATH=${glibc}/lib/locale LC_ALL=C.UTF-8 ${glibc.bin}/bin/locale charmap
        '';
      expected = "ok\nUTF-8";
    };
    loader-hardening = {
      script = ''
        ${binutils}/bin/readelf -d ${glibc}/lib/libc.so.6 > libc.dynamic
        ${binutils}/bin/readelf -l ${glibc}/lib/libc.so.6 > libc.programs
        grep -E 'BIND_NOW|FLAGS.*NOW' libc.dynamic >&2
        grep GNU_RELRO libc.programs >&2
        ${binutils}/bin/readelf -Ws ${glibc}/lib/libc.so.6 | grep __stack_chk_fail >&2
        ${binutils}/bin/objdump -d ${glibc}/lib/libc.so.6 > libc.instructions
        grep -E 'call.*<__stack_chk_fail' libc.instructions >&2
        ${glibc}/${glibc.platform.dynamicLinker} --list-diagnostics > diagnostics
        grep -F 'path.prefix="${glibc}"' diagnostics >&2
        grep -F 'path.sysconfdir="${glibc}/etc"' diagnostics >&2
        ${spec.python3Minimal}/bin/python3 -B - <<'PY'
        from pathlib import Path
        loader = Path('${glibc}/${glibc.platform.dynamicLinker}').read_bytes()
        for path in ('${glibc}/etc/ld.so.preload', '${glibc}/etc/ld.so.cache'):
            assert path.encode() + b'\0' in loader, path
        PY
        printf ok
      '';
      expected = "ok";
    };
    output-layout = {
      script = ''
        test "$(readlink ${glibc}/lib64)" = lib
        test ! -e ${glibc}/bin
        test ! -e ${glibc}/sbin
        for file in include/stdio.h include/linux/version.h include/asm/unistd.h \
          lib/libc.so.6 lib/libc.so lib/libc.a lib/libc_nonshared.a lib/crt1.o lib/Scrt1.o lib/rcrt1.o \
          lib/crti.o lib/crtn.o lib/libm.so.6 lib/libmvec.so.1 lib/gconv/gconv-modules \
          share/i18n/locales/C share/i18n/charmaps/UTF-8.gz; do
          test -s ${glibc}/$file
        done
        test -d ${glibc}/lib/locale/C.utf8
        for file in bin/ldd bin/mtrace bin/getconf bin/localedef bin/locale bin/iconv \
          bin/sprof bin/pldd bin/tzselect bin/zdump sbin/ldconfig sbin/iconvconfig sbin/nscd sbin/zic; do
          test -x ${glibc.bin}/$file
        done
        printf ok
      '';
      expected = "ok";
    };
    rebound-tools = {
      script = ''
        PATH=/no-tools ${tools}/bin/ldd --version | head -1
        PATH=/no-tools ${tools}/bin/mtrace --version | head -1
        grep -F 'eval "exec ${spec.perl}/bin/perl -S $0 $@"' ${tools}/bin/mtrace >&2
      '';
      expected = "ldd ${glibc.version}\nmtrace ${glibc.version}";
    };
  };
}
