{ package }:
let
  s = package.specification;
  cc = package.tvp.cc;
  triple = "x86_64-unknown-linux-gnu";
in
package.testContext.mkSuite {
  inherit package;
  tests = {
    version = {
      script = "rustc --version | ${s.gawk}/bin/awk '{print $2}'";
      expected = package.version;
    };
    compile = {
      script = ''rustc ${./fixtures/hello.rs} -o hello; ./hello'';
      expected = "tvp";
      tools = [ cc ];
    };
    edition-2024 = {
      script = ''rustc --edition 2024 ${./fixtures/edition2024.rs} -o ed; ./ed'';
      expected = "6";
      tools = [ cc ];
    };
    staticlib = {
      script = ''rustc --crate-type=staticlib ${./fixtures/hello.rs} -o libtvp.a; test -s libtvp.a && echo ok'';
      expected = "ok";
    };
    host-tools = {
      script = ''
        host=${package}/lib/rustlib/${triple}/bin
        "$host/rust-objcopy" --version > objcopy
        "$host/wasm-component-ld" --help > component
        "$host/rust-lld" -flavor gnu --version > lld
        "$host/gcc-ld/ld.lld" --version > elf
        "$host/gcc-ld/ld64.lld" --version > macho
        "$host/gcc-ld/lld-link" --version > coff
        "$host/gcc-ld/wasm-ld" --version > wasm
        ${s.grep}/bin/grep -q LLVM objcopy
        ${s.grep}/bin/grep -q LLD elf
        ${s.grep}/bin/grep -q LLD coff
        test -s macho && test -s wasm && test -s component
        printf '{"ApiVersionCheck":{}}\n' | RUST_ANALYZER_INTERNALS_DO_NOT_USE=1 ${package}/libexec/rust-analyzer-proc-macro-srv > proc-macro
        ${s.python}/bin/python3 -B -c 'import json; d=json.load(open("proc-macro")); assert isinstance(d["ApiVersionCheck"], int) and d["ApiVersionCheck"] > 0'
        test -s proc-macro
        rustc --print target-libdir | ${s.grep}/bin/grep -Fx '${package}/lib/rustlib/${triple}/lib' > /dev/null
        # Discover and use the installed LLD through rustc's supported linker flag.
        rustc -C linker-flavor=gcc -C link-arg=-fuse-ld=lld ${./fixtures/hello.rs} -o linked
        ./linked
      '';
      tools = [
        cc
        s.grep
      ];
      expected = "tvp";
    };
    target-bytes = {
      script = ''
        ${s.python}/bin/python3 -B ${./target-bytes.py} ${s.src} ${package.artifact} ${package}
      '';
      tools = [ s.python ];
      expected = "pinned target payload preserved";
    };
    dynamic-std = {
      script = ''
        rustc -C prefer-dynamic ${./fixtures/hello.rs} -o dynamic
        LD_LIBRARY_PATH=${package}/lib/rustlib/${triple}/lib:${s.runtime.libc}/lib:${s.runtime.compiler}/lib ./dynamic
      '';
      tools = [ cc ];
      expected = "tvp";
    };
  };
}
