# 37.0.1: owned binary/data repack with pristine installed payload and final-only host adaptation.
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
  pname = "android-platform-tools";
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
    ;
  testsEnabled = true;
  runtime = {
    shell = "${final.bash}/bin/bash";
    loader = "${final.runtimeLibc}/lib/ld-linux-x86-64.so.2";
    libraries = [
      final.runtimeLibc
      final.runtimeCompiler
    ];
  };
  environment.tools = [
    final.coreutils
    final.sed
    final.grep
  ];
  plan = steps.sequence [
    (
      (command "android-platform-tools.install-payload" ''
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
    (steps.split "android-platform-tools.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (command "android-platform-tools.metadata" ''
      component="$out/libexec/android-sdk/${final.sdkPath}"
      cp ${final.packageMetadata} "$component/package.xml"
      cp ${../../android-sdk-license.txt} "$component/TVP-SDK-LICENSE.txt"
      mkdir -p "$out/bin"

    '')

    (outputs.hostELF {
      inherit (final) python binutils patchelf;
      paths = [
        "libexec/android-sdk/${final.sdkPath}"
        "libexec/android-sdk/${final.sdkPath}/lib64"
      ];
      patterns = [ ];
      loader = final.runtime.loader;
      libraries = final.runtime.libraries;
    })
    (command "android-platform-tools.publish" ''
      component="$out/libexec/android-sdk/${final.sdkPath}"
      for tool in adb fastboot etc1tool hprof-conv sqlite3 make_f2fs make_f2fs_casefold mke2fs; do ln -s "$component/$tool" "$out/bin/"; done
    '')
  ];
  tvp.android = {
    sdkPath = final.sdkPath;
    componentPath = "libexec/android-sdk/${final.sdkPath}";
  };
  meta = {
    description = "Pinned Android SDK component: android-platform-tools";
    homepage = "https://developer.android.com/tools";
    license = lib.licenses.unfree;
    sourceProvenance = [
      lib.sourceTypes.binaryNativeCode
      lib.sourceTypes.binaryBytecode
    ];
    platforms = [ "x86_64-linux" ];
  };
}
