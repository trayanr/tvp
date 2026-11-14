# Complete android-ndk production procedure; released profile facts stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
  gnumake,
  runtimeCompiler,
  runtimeLibc,
  unzip,
  zlib,
  sourceLayout ? { },
  installedInterface ? { },
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  command = name: run: {
    inherit name run;
    tools = [
      final.coreutils
      tools.sed
      tools.grep
      tools.diffutils
    ];
  };
in
{
  pname = "android-ndk";
  inherit
    base
    src
    version
    runtimeLibc
    runtimeCompiler
    unzip
    zlib
    gnumake
    ;
  inherit (tools) bash coreutils;
  sourceLayout = {
    archiveRoot = "android-ndk-r28c";
    packageMetadata = ./metadata-28.2.13676358.xml;
  } // sourceLayout;
  installedInterface = {
    sdkPath = "ndk/28.2.13676358";
  } // installedInterface;
  testsEnabled = true;
  runtime = {
    shell = "${final.bash}/bin/bash";
    loader = "${final.runtimeLibc}/lib/ld-linux-x86-64.so.2";
    libraries = [
      final.runtimeLibc
      final.runtimeCompiler
    ] ++ [ final.zlib ];
  };
  environment.tools = [
    final.coreutils
    tools.sed
    tools.grep
  ];
  plan = steps.sequence [
    (
      (command "android-ndk.install-payload" ''
        mkdir source
        ${final.unzip}/bin/unzip -q ${final.src} -d source
        test -d "source/${final.sourceLayout.archiveRoot}"
        mkdir -p "$out/libexec/android-sdk/${final.installedInterface.sdkPath}"
        cp -a "source/${final.sourceLayout.archiveRoot}/." "$out/libexec/android-sdk/${final.installedInterface.sdkPath}/"
      '')
      // {
        tools = [ final.coreutils ] ++ [ final.unzip ];
      }
    )
    (steps.split "android-ndk.finalize")
    (outputs.copyArtifacts { })
    (command "android-ndk.metadata" ''
      component="$out/libexec/android-sdk/${final.installedInterface.sdkPath}"
      cp ${final.sourceLayout.packageMetadata} "$component/package.xml"
      cp ${../android-sdk-license.txt} "$component/TVP-SDK-LICENSE.txt"
      mkdir -p "$out/bin"
      rm "$component/prebuilt/linux-x86_64/bin/make"
      ln -s ${final.gnumake}/bin/make "$component/prebuilt/linux-x86_64/bin/make"

    '')
    (outputs.shebangs {

      names = [
        "sh"
        "bash"
      ];
      interpreter = final.runtime.shell;
      paths = [
        "libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/bin"
        "libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/libexec"
        "libexec/android-sdk/${final.installedInterface.sdkPath}/ndk-build"
        "libexec/android-sdk/${final.installedInterface.sdkPath}/build"
        "libexec/android-sdk/${final.installedInterface.sdkPath}/prebuilt/linux-x86_64/bin"
      ];
    })
    # r28c's host analysis scripts use the bundled Python 3.11 and Perl.
    # Bind installed interpreters only after the pristine payload copy.
    (
      (outputs.shebangs {

        names = [
          "python"
          "python3"
        ];
        selfInterpreter = "libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/python3/bin/python3.11";
        paths = [
          "libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/bin"
          "libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/libexec"
          "libexec/android-sdk/${final.installedInterface.sdkPath}/build"
        ];
      })
      // {
        name = "android-ndk.python-shebangs";
      }
    )
    (
      (outputs.shebangs {

        names = [ "perl" ];
        interpreter = "${tools.perl}/bin/perl";
        paths = [
          "libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/bin"
          "libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/libexec"
        ];
      })
      // {
        name = "android-ndk.perl-shebangs";
      }
    )
    (outputs.hostELF {

      paths = [
        "libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/bin"
        "libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/lib"
        "libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/lib/x86_64-unknown-linux-gnu"
        "libexec/android-sdk/${final.installedInterface.sdkPath}/prebuilt/linux-x86_64/bin"
        "libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/python3/bin"
        "libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/python3/lib"
      ];
      patterns = [
        "libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/python3/lib/python*/lib-dynload"
        "libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/lib/python*/site-packages/lldb"
      ];
      loader = final.runtime.loader;
      libraries = final.runtime.libraries;
    })
    (command "android-ndk.publish" ''
      component="$out/libexec/android-sdk/${final.installedInterface.sdkPath}"
      for tool in "$component/toolchains/llvm/prebuilt/linux-x86_64/bin/"*; do if test -x "$tool"; then ln -s "$tool" "$out/bin/"; fi; done
      cat > "$out/bin/ndk-build" <<EOF
      #!${final.runtime.shell}
      exec "$component/ndk-build" "\$@"
      EOF
      chmod +x "$out/bin/ndk-build"
      # Full target sysroot and Clang resource comparisons remain mandatory.
      ${tools.diffutils}/bin/diff -qr "$TVP_ARTIFACT_ROOT/libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/sysroot" "$component/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
      ${tools.diffutils}/bin/diff -qr "$TVP_ARTIFACT_ROOT/libexec/android-sdk/${final.installedInterface.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/lib/clang" "$component/toolchains/llvm/prebuilt/linux-x86_64/lib/clang"

    '')
  ];
  tvp.android = {
    sdkPath = final.installedInterface.sdkPath;
    componentPath = "libexec/android-sdk/${final.installedInterface.sdkPath}";
  };
  meta = {
    description = "Pinned Android SDK component: android-ndk";
    homepage = "https://developer.android.com/tools";
    license = lib.licenses.unfree;
    sourceProvenance = [
      lib.sourceTypes.binaryNativeCode
      lib.sourceTypes.binaryBytecode
    ];
    platforms = [ "x86_64-linux" ];
  };
}
