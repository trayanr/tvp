{
  pkgs,
  tvpLib,
  package,
}:
let
  binutils = package;
  cc = [ package.specification.base.compiler ];
  # GCC normally uses its own wrapped binutils. Check selection explicitly so
  # consumer tests cannot accidentally exercise the borrowed base's linker.
  selectTools = ''
    for tool in as ld; do
      actual=$(cc -B${binutils}/bin/ -print-prog-name="$tool")
      test "$actual" = "${binutils}/bin/$tool"
    done
  '';
in
package.testContext.mkSuite {
  tools = with package.specification; [
    sed
    grep
    gawk
    diffutils
    findutils
  ];
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
      tools =
        cc
        ++ (with package.specification; [
          sed
          grep
          diffutils
        ]);
    };
    cxx = {
      script =
        selectTools
        + ''
          # Raw ld does not inject the runtime RPATHs normally supplied by the
          # borrowed bintools wrapper. Name this compiler's C++ runtime.
          c++ -B${binutils}/bin/ ${./fixtures/hello.cc} \
            -Wl,-rpath,${builtins.head package.specification.base.compiler.runtimeDirectories} -o hello
          ./hello
        '';
      expected = "42";
      tools =
        cc
        ++ (with package.specification; [
          sed
          grep
          diffutils
        ]);
    };
    lto = {
      script =
        selectTools
        + ''
          cc -B${binutils}/bin/ -flto ${./fixtures/hello.c} -o hello
          ./hello
        '';
      expected = "tvp";
      tools =
        cc
        ++ (with package.specification; [
          sed
          grep
          diffutils
        ]);
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
      tools =
        cc
        ++ (with package.specification; [
          sed
          grep
          diffutils
        ]);
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
      tools =
        cc
        ++ (with package.specification; [
          sed
          grep
          diffutils
        ]);
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
      tools =
        cc
        ++ (with package.specification; [
          sed
          grep
          diffutils
        ]);
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
      tools =
        cc
        ++ (with package.specification; [
          sed
          grep
          diffutils
        ]);
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
    gprofng-collect-display = {
      tools = with package.specification; [
        sed
        grep
        diffutils
      ];
      script = ''
        cat > profile.c <<'EOF'
        #include <stdio.h>
        #include <stdlib.h>
        #include <pthread.h>
        int main(void) {
          pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;
          volatile unsigned long n = 0;
          void *p = malloc(1024);
          FILE *f = fopen("profile-output", "w");
          if (!p || !f) return 1;
          pthread_mutex_lock(&m);
          for (unsigned long i = 0; i < 20000000; ++i) n += i;
          fprintf(f, "%lu", n); fclose(f); free(p);
          pthread_mutex_unlock(&m); return 0;
        }
        EOF
        "$CC" -g -pthread profile.c -o profile
        ${package}/bin/gprofng collect app -O sample.er -p on -H on -i on -s all ./profile >collect.out 2>collect.err
        cat collect.out collect.err >&2
        test -s sample.er/log.xml
        ${package}/bin/gprofng display text -functions sample.er >report 2>display.err
        cat report display.err >&2
        grep -q main report
        ${package}/bin/gprofng display html --help >html-help
        grep -q 'Usage: gprofng display html' html-help
        for module in collector heap iotrace sync; do
          test -s ${package}/lib/gprofng/libgp-$module.so
        done
        printf ok
      '';
      expected = "ok";
    };
    development-interfaces = {
      script = ''
        for archive in bfd opcodes ctf ctf-nobfd sframe gprofng iberty; do
          test -s ${package}/lib/lib$archive.a
        done
        for header in bfd.h bfdlink.h ctf-api.h sframe-api.h libiberty/libiberty.h; do
          test -s ${package}/include/$header
        done
        test -d ${package}/lib/bfd-plugins
        printf ok
      '';
      expected = "ok";
    };
    helper-boundaries = {
      tools = [ package.specification.python ];
      script = ''${package.specification.python}/bin/python3 -B ${./helper-safety.py} ${../native} ${../../../../lib/native-output}'';
      expected = "boundaries-ok";
    };
    development-consumer = {
      libraries = [ package ];
      script = ''
        cat > interfaces.c <<'EOF'
        #define PACKAGE "tvp-consumer"
        #define PACKAGE_VERSION "1"
        #include <bfd.h>
        #include <ctf-api.h>
        #include <stdio.h>
        int main(void) {
          int err = 0;
          bfd_init();
          ctf_dict_t *dict = ctf_create(&err);
          if (!dict) return 1;
          ctf_dict_close(dict);
          puts("interfaces-ok"); return 0;
        }
        EOF
        "$CC" interfaces.c -lctf -lbfd -lsframe ${package}/lib/libiberty.a -lz -lzstd -o interfaces
        ./interfaces
      '';
      expected = "interfaces-ok";
    };
  };
}
