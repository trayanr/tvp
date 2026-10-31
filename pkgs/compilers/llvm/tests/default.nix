{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''llvm-config --version'';
      expected = package.version;
    };
    c = {
      script = ''clang ${./fixtures/hello.c} -o hello; ./hello'';
      expected = "42";
    };
    cxx = {
      script = ''clang++ ${./fixtures/hello.cc} -o hello; ./hello'';
      expected = "42";
    };
    linker = {
      script = ''clang -fuse-ld=lld ${./fixtures/hello.c} -o hello; ./hello'';
      expected = "42";
    };
    ir = {
      script = ''clang -S -emit-llvm ${./fixtures/codegen.c} -o answer.ll; llvm-as answer.ll -o answer.bc; llvm-dis answer.bc -o output.ll; grep -q 'ret i32 42' output.ll; printf preserved'';
      expected = "preserved";
    };
    aarch64-codegen = {
      script = ''
        clang --target=aarch64-unknown-linux-gnu -ffreestanding -nostdinc -c ${./fixtures/codegen.c} -o answer.o
        llvm-readelf -h answer.o > elf-header
        grep -q AArch64 elf-header
        printf aarch64
      '';
      expected = "aarch64";
    };
    loader = {
      script = ''clang ${./fixtures/hello.c} -o hello; patchelf --print-interpreter hello'';
      expected = package.tvp.dynamicLinker;
      extraInputs = [ package.tvp.deps.patchelf ];
    };
  };
}
