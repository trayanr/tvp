# Complete android-platform production procedure; released profile facts stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
  runtimeCompiler,
  runtimeLibc,
  unzip,
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
  pname = "android-platform";
  inherit
    base
    src
    version
    runtimeLibc
    runtimeCompiler
    unzip
    ;
  inherit (tools) bash coreutils;
  sourceLayout = { } // sourceLayout;
  installedInterface = { } // installedInterface;
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
    tools.sed
    tools.grep
  ];
  plan = steps.sequence [
    (
      (command "android-platform.install-payload" ''
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
    (steps.split "android-platform.finalize")
    (outputs.copyArtifacts { })
    (command "android-platform.metadata" ''
      component="$out/libexec/android-sdk/${final.installedInterface.sdkPath}"
      cp ${final.sourceLayout.packageMetadata} "$component/package.xml"
      cp ${../android-sdk-license.txt} "$component/TVP-SDK-LICENSE.txt"
      mkdir -p "$out/bin"

    '')

    (command "android-platform.publish" ''
      component="$out/libexec/android-sdk/${final.installedInterface.sdkPath}"
      test -s "$out/libexec/android-sdk/${final.installedInterface.sdkPath}/android.jar"
    '')
  ];
  tvp.android = {
    sdkPath = final.installedInterface.sdkPath;
    componentPath = "libexec/android-sdk/${final.installedInterface.sdkPath}";
    apiLevel = final.installedInterface.apiLevel;
  };
  meta = {
    description = "Android platform API ${final.installedInterface.apiLevel}, revision preserved in package version";
    homepage = "https://developer.android.com/tools";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    platforms = [ "x86_64-linux" ];
  };
}
