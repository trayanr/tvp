{
  pkgs,
  tvpLib,
  glibc,
}:
let
  gcc = glibc.tvp.deps.gcc;
  flags = "-B${glibc}/lib/ -isystem ${glibc}/include -L${glibc}/lib -Wl,-dynamic-linker,${glibc}/${glibc.platform.dynamicLinker} -Wl,-rpath,${glibc}/lib -Wl,-rpath,${gcc}/lib";
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = glibc;
  tests = {
    version = {
      script = ''${glibc.bin}/bin/getconf GNU_LIBC_VERSION'';
      expected = "glibc ${glibc.version}";
    };
    runtime = {
      script = ''
        ${gcc}/bin/gcc ${flags} ${./fixtures/runtime.c} -pthread -ldl -lm -o runtime
        ${glibc.tvp.deps.binutils}/bin/readelf -l runtime | grep -F '${glibc}/${glibc.platform.dynamicLinker}' >&2
        ./runtime ${glibc.version}
      '';
      expected = "ok";
    };
    static = {
      script = ''
        ${gcc}/bin/gcc ${flags} -static ${./fixtures/static.c} -o static
        test -z "$(${glibc.tvp.deps.binutils}/bin/readelf -l static | grep INTERP)"
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
      script = ''
        ${gcc}/bin/gcc ${flags} ${./fixtures/static.c} -o dynamic
        ${glibc.bin}/bin/ldd ./dynamic | awk '/libc.so.6 =>/ { print $3 }'
      '';
      expected = "${glibc}/lib/libc.so.6";
    };
  };
}
