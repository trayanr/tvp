{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''sed -n 's/^Pkg.Revision *= *//p' ${package}/${package.tvp.android.componentPath}/source.properties'';
      expected = package.version;
    };
    cross-c = {
      script = ''
        aarch64-linux-android24-clang ${./hello.c} -o hello
        # Finish readelf before grep -q can close its output pipe (LLVM exits 74).
        llvm-readelf -h hello > elf-header
        grep -q AArch64 elf-header
        llvm-readelf -l hello > program-headers
        grep -q '/system/bin/linker64' program-headers
        llvm-readelf -d hello > dynamic
        grep -q 'libc.so' dynamic
        printf android-arm64
      '';
      expected = "android-arm64";
    };
    cross-cxx = {
      script = ''
        aarch64-linux-android24-clang++ ${./hello.cc} -o hello
        llvm-readelf -d hello > dynamic
        grep -q 'libc++_shared.so' dynamic
        llvm-readelf -h hello > elf-header
        grep -q AArch64 elf-header
        printf android-cxx
      '';
      expected = "android-cxx";
    };
    ndk-build = {
      script = ''
        mkdir jni
        cp ${./Android.mk} jni/Android.mk
        cp ${./answer.c} jni/answer.c
        ndk-build NDK_PROJECT_PATH="$PWD" APP_ABI=arm64-v8a APP_PLATFORM=android-24 > build.log
        llvm-readelf -h libs/arm64-v8a/libanswer.so > elf-header
        grep -q AArch64 elf-header
        llvm-readelf -s libs/arm64-v8a/libanswer.so > symbols
        grep -q tvp_answer symbols
        printf ndk-make-ok
      '';
      expected = "ndk-make-ok";
    };
  };
}
