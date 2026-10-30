{
  pkgs,
  tvpLib,
  gcc,
}:
let
  libc = gcc.tvp.deps.glibc;
  flags = "-B${libc}/lib/ -idirafter ${pkgs.lib.getDev libc}/include -L${libc}/lib -Wl,-dynamic-linker,${libc}/${gcc.platform.dynamicLinker} -Wl,-rpath,${gcc}/lib -Wl,-rpath,${libc}/lib";
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = gcc;
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
        test "$(${gcc}/bin/gcc -print-prog-name=as)" = "${gcc.tvp.deps.binutils}/bin/as"
        test "$(${gcc}/bin/gcc -print-prog-name=ld)" = "${gcc.tvp.deps.binutils}/bin/ld"
        printf ok
      '';
      expected = "ok";
    };
    tool-overrides = {
      script = ''
        mkdir tools
        cp ${./fixtures/tool.sh} tools/as
        cp ${./fixtures/tool.sh} tools/ld
        chmod +x tools/as tools/ld
        export TVP_TOOL_TEST_LOG="$PWD/selected-tools"
        export TVP_TOOL_REAL=${gcc.tvp.deps.binutils}/bin
        test "$(${gcc}/bin/gcc -B"$PWD/tools/" -print-prog-name=as)" = "$PWD/tools/as"
        test "$(${gcc}/bin/gcc -B"$PWD/tools/" -print-prog-name=ld)" = "$PWD/tools/ld"
        ${gcc}/bin/gcc -B"$PWD/tools/" ${flags} ${./fixtures/hello.c} -o hello
        grep -Fxq as selected-tools
        grep -Fxq ld selected-tools
        ./hello
      '';
      expected = "42";
    };
  };
}
// {
  tracker = import ./tracker.nix { inherit pkgs gcc; };
}
