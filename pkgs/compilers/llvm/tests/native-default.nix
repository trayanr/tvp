{ package }:
let
  s = package.specification;
  # Independent production-shaped construction followed by the original raw
  # checks. No public final output, finalizer, wrapper or artifact is consumed.
  upstream = package.edit (
    spec:
    (builtins.removeAttrs spec [ "artifactName" ])
    // {
      pname = "${spec.pname}-upstream";
      validationRole = "upstream-execution";
      plan = spec.upstreamPlan;
      passthru = { };
    }
  );
in
package.testContext.mkSuite {
  inherit package;
  tools = [
    s.coreutils
    s.binutils
    s.patchelf
    s.helperPython
  ];
  tests = {
    upstream = {
      script = ''test -d ${upstream}; printf passed'';
      expected = "passed";
    };
    version = {
      script = ''llvm-config --version'';
      expected = package.version;
    };
    c = {
      script = ''clang ${./fixtures/hello.c} -o hello; ./hello'';
      expected = "42";
    };
    cxx = {
      script = ''
        clang++ ${./fixtures/hello.cc} -o hello
        ${s.runtime.loader} --list ./hello > runtime-list
        ${s.helperPython}/bin/python3 -B - <<'PYTHON'
        from pathlib import Path
        text = Path('runtime-list').read_text()
        for path in ['${s.runtime.target.cxxRuntime}/lib/libstdc++', '${s.runtime.target.gccRuntime}/lib/libgcc_s', '${s.runtime.target.libc}/lib/libc']:
            assert path in text, (path, text)
        PYTHON
        ./hello
      '';
      expected = "42";
    };
    linker = {
      script = ''clang -fuse-ld=lld ${./fixtures/hello.c} -o hello; ./hello'';
      expected = "42";
    };
    ir = {
      script = ''clang -S -emit-llvm ${./fixtures/codegen.c} -o answer.ll; llvm-as answer.ll -o answer.bc; llvm-dis answer.bc -o output.ll; ${s.helperPython}/bin/python3 -B -c 'assert "ret i32 42" in open("output.ll").read(); print("preserved")' '';
      tools = [ s.helperPython ];
      expected = "preserved";
    };
    aarch64-codegen = {
      script = ''
        clang --target=aarch64-unknown-linux-gnu -ffreestanding -nostdinc -c ${./fixtures/codegen.c} -o answer.o
        llvm-readelf -h answer.o > elf-header
        ${s.helperPython}/bin/python3 -B -c 'assert "AArch64" in open("elf-header").read(); print("aarch64")'
      '';
      tools = [ s.helperPython ];
      expected = "aarch64";
    };
    preprocessor = {
      script = ''
        clang-cpp -P ${./fixtures/preprocessor.c} > preprocessed.c
        ${s.helperPython}/bin/python3 -B -c 'from pathlib import Path; assert Path("preprocessed.c").read_text().split() == ["42"]; print("42")'
      '';
      expected = "42";
    };
    loader = {
      script = ''clang ${./fixtures/hello.c} -o hello; ${s.patchelf}/bin/patchelf --print-interpreter hello'';
      expected = s.runtime.loader;
    };
  };
}
