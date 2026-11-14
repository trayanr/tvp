{
  pkgs,
  tvpLib,
  binutils,
}:
let
  cc = [ binutils.tvp.cc ];
  # GCC normally uses its own wrapped binutils. Check selection explicitly so
  # consumer tests cannot accidentally exercise the borrowed base's linker.
  selectTools = ''
    for tool in as ld; do
      actual=$(cc -B${binutils}/bin/ -print-prog-name="$tool")
      test "$actual" = "${binutils}/bin/$tool"
    done
  '';
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = binutils;
  tests = {
    version = {
      script = ''
        for tool in as ld ar readelf; do
          "$tool" --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
        done
      '';
      expected = pkgs.lib.concatStringsSep "\n" (pkgs.lib.replicate 4 binutils.version);
    };
    tools = {
      script = ''
        for tool in addr2line ar as c++filt elfedit gprof gprofng ld nm objcopy objdump ranlib readelf size strings strip; do
          test -x ${binutils}/bin/"$tool"
          ${binutils}/bin/"$tool" --version > /dev/null
        done
        printf ok
      '';
      expected = "ok";
    };
    assemble-link = {
      script = ''
        as ${./fixtures/start.s} -o start.o
        ld -o start start.o
        ./start
      '';
      expected = "tvp";
    };
    c = {
      script =
        selectTools
        + ''
          cc -B${binutils}/bin/ ${./fixtures/hello.c} -o hello
          ./hello
        '';
      expected = "tvp";
      extraInputs = cc;
    };
    cxx = {
      script =
        selectTools
        + ''
          # Raw ld does not inject the runtime RPATHs normally supplied by the
          # borrowed bintools wrapper. Name this compiler's C++ runtime.
          c++ -B${binutils}/bin/ ${./fixtures/hello.cc} \
            -Wl,-rpath,${pkgs.lib.getLib binutils.tvp.cc.cc}/lib -o hello
          ./hello
        '';
      expected = "42";
      extraInputs = cc;
    };
    lto = {
      script =
        selectTools
        + ''
          cc -B${binutils}/bin/ -flto ${./fixtures/hello.c} -o hello
          ./hello
        '';
      expected = "tvp";
      extraInputs = cc;
    };
    archive = {
      script =
        selectTools
        + ''
          cc -B${binutils}/bin/ -c ${./fixtures/answer.c} -o answer.o
          ar crs first.a answer.o
          touch -d '2001-02-03 04:05:06 UTC' answer.o
          ar crs second.a answer.o
          cmp first.a second.a
          cc -B${binutils}/bin/ ${./fixtures/call.c} first.a -o call
          ./call
        '';
      expected = "42";
      extraInputs = cc;
    };
    shared = {
      script =
        selectTools
        + ''
          cc -B${binutils}/bin/ -fPIC -c ${./fixtures/answer.c} -o answer.o
          ld -shared -soname libanswer.so answer.o -o libanswer.so
          cc -B${binutils}/bin/ ${./fixtures/call.c} -L. -lanswer -Wl,-rpath,"$PWD" -o call
          ./call
        '';
      expected = "42";
      extraInputs = cc;
    };
    debug-compression = {
      script =
        selectTools
        + ''
          cc -B${binutils}/bin/ -g ${./fixtures/hello.c} -o hello
          objcopy --dump-section .debug_info=original.info hello
          for format in zlib zstd; do
            objcopy --compress-debug-sections="$format" hello compressed
            readelf -SW compressed | grep '\.debug_info ' | grep -qE '[[:space:]]C[[:space:]]'
            readelf --debug-dump=info compressed | grep -q DW_TAG_compile_unit
            objcopy --decompress-debug-sections compressed restored
            objcopy --dump-section .debug_info=restored.info restored
            cmp original.info restored.info
          done
          printf ok
        '';
      expected = "ok";
      extraInputs = cc;
    };
    strip = {
      script =
        selectTools
        + ''
          cc -B${binutils}/bin/ -g ${./fixtures/hello.c} -o hello
          readelf -SW hello | grep -q '\.debug_info '
          strip --strip-debug hello
          if readelf -SW hello | grep -q '\.debug_info '; then exit 1; fi
          ./hello
        '';
      expected = "tvp";
      extraInputs = cc;
    };
    documentation = {
      script = ''
        for manual in as bfd binutils gprof gprofng ld; do
          test -s ${binutils}/share/info/"$manual".info
        done
        printf ok
      '';
      expected = "ok";
    };
  };
}
