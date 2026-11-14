# 23.0: owned binary/data repack with pristine installed payload and final-only host adaptation.
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
  androidCli,
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
  pname = "android-commandline-tools";
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
    androidCli
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
      (command "android-commandline-tools.install-payload" ''
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
    (steps.split "android-commandline-tools.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (command "android-commandline-tools.metadata" ''
              component="$out/libexec/android-sdk/${final.sdkPath}"
              cp ${final.packageMetadata} "$component/package.xml"
              cp ${../../android-sdk-license.txt} "$component/TVP-SDK-LICENSE.txt"
              mkdir -p "$out/bin"
              rm "$component/bin/android"
              ln -s ${final.androidCli}/bin/android "$component/bin/android"
      for script in "$component"/bin/*; do
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
      paths = [ "libexec/android-sdk/${final.sdkPath}/bin" ];
    })
    (outputs.hostELF {
      inherit (final) python binutils patchelf;
      paths = [ "libexec/android-sdk/${final.sdkPath}/bin" ];
      patterns = [ ];
      loader = final.runtime.loader;
      libraries = final.runtime.libraries;
    })
    (command "android-commandline-tools.publish" ''
      component="$out/libexec/android-sdk/${final.sdkPath}"
      for tool in "$component/bin/"*; do if test -x "$tool"; then ln -s "$tool" "$out/bin/"; fi; done
    '')
  ];
  tvp.android = {
    sdkPath = final.sdkPath;
    componentPath = "libexec/android-sdk/${final.sdkPath}";
  };
  meta = {
    description = "Pinned Android SDK component: android-commandline-tools";
    homepage = "https://developer.android.com/tools";
    license = lib.licenses.unfree;
    sourceProvenance = [
      lib.sourceTypes.binaryNativeCode
      lib.sourceTypes.binaryBytecode
    ];
    platforms = [ "x86_64-linux" ];
  };
}
