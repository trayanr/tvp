# API36 through37.1 declared platform distributions: owned binary/data repack with pristine installed payload and final-only host adaptation.
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
  apiLevel,
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
  pname = "android-platform";
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
    apiLevel
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
      (command "android-platform.install-payload" ''
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
    (steps.split "android-platform.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (command "android-platform.metadata" ''
      component="$out/libexec/android-sdk/${final.sdkPath}"
      cp ${final.packageMetadata} "$component/package.xml"
      cp ${../../android-sdk-license.txt} "$component/TVP-SDK-LICENSE.txt"
      mkdir -p "$out/bin"

    '')

    (command "android-platform.publish" ''
      component="$out/libexec/android-sdk/${final.sdkPath}"
      test -s "$out/libexec/android-sdk/${final.sdkPath}/android.jar"
    '')
  ];
  tvp.android = {
    sdkPath = final.sdkPath;
    componentPath = "libexec/android-sdk/${final.sdkPath}";
    apiLevel = final.apiLevel;
  };
  meta = {
    description = "Android platform API ${final.apiLevel}, revision preserved in package version";
    homepage = "https://developer.android.com/tools";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    platforms = [ "x86_64-linux" ];
  };
}
