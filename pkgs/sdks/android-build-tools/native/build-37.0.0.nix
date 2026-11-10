# 37.0.0: owned binary/data repack with pristine installed payload and final-only host adaptation.
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
  jdk,
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
  pname = "android-build-tools";
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
    jdk
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
      (command "android-build-tools.install-payload" ''
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
    (steps.split "android-build-tools.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (command "android-build-tools.metadata" ''
      component="$out/libexec/android-sdk/${final.sdkPath}"
      cp ${final.packageMetadata} "$component/package.xml"
      cp ${../../android-sdk-license.txt} "$component/TVP-SDK-LICENSE.txt"
      mkdir -p "$out/bin"
      for script in "$component/apksigner" "$component/d8"; do
        if test -f "$script" && ! test -L "$script" && head -c2 "$script" | grep -q '#!'; then
          ${final.sed}/bin/sed -i 's|/bin/ls|ls|g; 2i export JAVA_HOME=${final.jdk}\nexport PATH=${final.jdk}/bin:$PATH' "$script"
        fi
      done

    '')
    (outputs.shebangs {
      inherit (final) python;
      names = [
        "sh"
        "bash"
      ];
      interpreter = final.runtime.shell;
      paths = [
        "libexec/android-sdk/${final.sdkPath}/apksigner"
        "libexec/android-sdk/${final.sdkPath}/d8"
        "libexec/android-sdk/${final.sdkPath}/lld"
      ];
    })
    (outputs.hostELF {
      inherit (final) python binutils patchelf;
      paths = [
        "libexec/android-sdk/${final.sdkPath}"
        "libexec/android-sdk/${final.sdkPath}/lib64"
        "libexec/android-sdk/${final.sdkPath}/lld-bin"
      ];
      patterns = [ ];
      loader = final.runtime.loader;
      libraries = final.runtime.libraries;
    })
    (command "android-build-tools.publish" ''
      component="$out/libexec/android-sdk/${final.sdkPath}"
      for tool in aapt aapt2 aidl apksigner d8 dexdump zipalign; do ln -s "$component/$tool" "$out/bin/"; done
    '')
  ];
  tvp.android = {
    sdkPath = final.sdkPath;
    componentPath = "libexec/android-sdk/${final.sdkPath}";
  };
  meta = {
    description = "Pinned Android SDK component: android-build-tools";
    homepage = "https://developer.android.com/tools";
    license = lib.licenses.unfree;
    sourceProvenance = [
      lib.sourceTypes.binaryNativeCode
      lib.sourceTypes.binaryBytecode
    ];
    platforms = [ "x86_64-linux" ];
  };
}
