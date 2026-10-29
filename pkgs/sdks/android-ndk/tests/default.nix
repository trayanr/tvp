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
        llvm-readelf -h hello | grep -q AArch64
        llvm-readelf -l hello | grep -q '/system/bin/linker64'
        llvm-readelf -d hello | grep -q 'libc.so'
        printf android-arm64
      '';
      expected = "android-arm64";
    };
    cross-cxx = {
      script = ''
        aarch64-linux-android24-clang++ ${./hello.cc} -o hello
        llvm-readelf -d hello | grep -q 'libc++_shared.so'
        llvm-readelf -h hello | grep -q AArch64
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
        llvm-readelf -h libs/arm64-v8a/libanswer.so | grep -q AArch64
        llvm-readelf -s libs/arm64-v8a/libanswer.so | grep -q tvp_answer
        printf ndk-make-ok
      '';
      expected = "ndk-make-ok";
    };
  };
}
