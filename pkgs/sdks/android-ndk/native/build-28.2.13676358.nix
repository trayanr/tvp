# 28.2.13676358: owned binary/data repack with pristine installed payload and final-only host adaptation.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  python,
  binutils,
  patchelf,
  sed,
  grep,
  diffutils,
  findutils,
  runtimeLibc,
  runtimeCompiler,
  unzip,
  sdkPath,
  archiveRoot,
  packageMetadata,
  zlib,
  gnumake,
  perl,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command = name: run: {
    inherit name run;
    tools = [
      final.coreutils
      final.sed
      final.grep
      final.diffutils
    ];
  };
in
{
  pname = "android-ndk";
  inherit
    base
    src
    version
    bash
    coreutils
    python
    binutils
    patchelf
    sed
    grep
    diffutils
    findutils
    runtimeLibc
    runtimeCompiler
    unzip
    sdkPath
    archiveRoot
    packageMetadata
    zlib
    gnumake
    perl
    ;
  testsEnabled = true;
  runtime = {
    shell = "${final.bash}/bin/bash";
    loader = "${final.runtimeLibc}/lib/ld-linux-x86-64.so.2";
    libraries = [
      final.runtimeLibc
      final.runtimeCompiler
    ]
    ++ [ final.zlib ];
  };
  environment.tools = [
    final.coreutils
    final.sed
    final.grep
  ];
  plan = steps.sequence [
    (
      (command "android-ndk.install-payload" ''
        mkdir source
        ${final.unzip}/bin/unzip -q ${final.src} -d source
        test -d "source/${final.archiveRoot}"
        mkdir -p "$out/libexec/android-sdk/${final.sdkPath}"
        cp -a "source/${final.archiveRoot}/." "$out/libexec/android-sdk/${final.sdkPath}/"
      '')
      // {
        tools = [ final.coreutils ] ++ [ final.unzip ];
      }
    )
    (steps.split "android-ndk.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (command "android-ndk.metadata" ''
      component="$out/libexec/android-sdk/${final.sdkPath}"
      cp ${final.packageMetadata} "$component/package.xml"
      cp ${../../android-sdk-license.txt} "$component/TVP-SDK-LICENSE.txt"
      mkdir -p "$out/bin"
      rm "$component/prebuilt/linux-x86_64/bin/make"
      ln -s ${final.gnumake}/bin/make "$component/prebuilt/linux-x86_64/bin/make"

    '')
    (outputs.shebangs {
      inherit (final) python;
      names = [
        "sh"
        "bash"
      ];
      interpreter = final.runtime.shell;
      paths = [
        "libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/bin"
        "libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/libexec"
        "libexec/android-sdk/${final.sdkPath}/ndk-build"
        "libexec/android-sdk/${final.sdkPath}/build"
        "libexec/android-sdk/${final.sdkPath}/prebuilt/linux-x86_64/bin"
      ];
    })
    # r28c's host analysis scripts use the bundled Python 3.11 and Perl.
    # Bind installed interpreters only after the pristine payload copy.
    (
      (outputs.shebangs {
        inherit (final) python;
        names = [
          "python"
          "python3"
        ];
        selfInterpreter = "libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/python3/bin/python3.11";
        paths = [
          "libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/bin"
          "libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/libexec"
          "libexec/android-sdk/${final.sdkPath}/build"
        ];
      })
      // {
        name = "android-ndk.python-shebangs";
      }
    )
    (
      (outputs.shebangs {
        inherit (final) python;
        names = [ "perl" ];
        interpreter = "${final.perl}/bin/perl";
        paths = [
          "libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/bin"
          "libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/libexec"
        ];
      })
      // {
        name = "android-ndk.perl-shebangs";
      }
    )
    (outputs.hostELF {
      inherit (final) python binutils patchelf;
      paths = [
        "libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/bin"
        "libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/lib"
        "libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/lib/x86_64-unknown-linux-gnu"
        "libexec/android-sdk/${final.sdkPath}/prebuilt/linux-x86_64/bin"
        "libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/python3/bin"
        "libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/python3/lib"
      ];
      patterns = [
        "libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/python3/lib/python*/lib-dynload"
        "libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/lib/python*/site-packages/lldb"
      ];
      loader = final.runtime.loader;
      libraries = final.runtime.libraries;
    })
    (command "android-ndk.publish" ''
      component="$out/libexec/android-sdk/${final.sdkPath}"
      for tool in "$component/toolchains/llvm/prebuilt/linux-x86_64/bin/"*; do if test -x "$tool"; then ln -s "$tool" "$out/bin/"; fi; done
      cat > "$out/bin/ndk-build" <<EOF
      #!${final.runtime.shell}
      exec "$component/ndk-build" "\$@"
      EOF
      chmod +x "$out/bin/ndk-build"
      # Full target sysroot and Clang resource comparisons remain mandatory.
      ${final.diffutils}/bin/diff -qr "$TVP_ARTIFACT_ROOT/libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/sysroot" "$component/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
      ${final.diffutils}/bin/diff -qr "$TVP_ARTIFACT_ROOT/libexec/android-sdk/${final.sdkPath}/toolchains/llvm/prebuilt/linux-x86_64/lib/clang" "$component/toolchains/llvm/prebuilt/linux-x86_64/lib/clang"

    '')
  ];
  tvp.android = {
    sdkPath = final.sdkPath;
    componentPath = "libexec/android-sdk/${final.sdkPath}";
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
