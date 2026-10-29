{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''patchelf --version | awk '{print $2}' '';
      expected = package.version;
    };
    elf = {
      script = ''
        cc ${./fixtures/hello.c} -o hello
        interpreter=$(patchelf --print-interpreter hello)
        patchelf --set-rpath "$PWD/unused:${package.tvp.cc.libc}/lib" hello
        test "$(patchelf --print-rpath hello)" = "$PWD/unused:${package.tvp.cc.libc}/lib"
        patchelf --set-interpreter "$interpreter" hello
        ./hello
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
  };
}
