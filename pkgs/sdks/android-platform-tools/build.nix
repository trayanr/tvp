# Complete android-platform-tools production procedure; released profile facts stay explicit.
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
  pname = "android-platform-tools";
  inherit
    base
    src
    version
    runtimeLibc
    runtimeCompiler
    unzip
    ;
  inherit (tools) bash coreutils;
  sourceLayout = {
    archiveRoot = "platform-tools";
    packageMetadata = ./metadata-37.0.1.xml;
  } // sourceLayout;
  installedInterface = {
    sdkPath = "platform-tools";
  } // installedInterface;
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
      (command "android-platform-tools.install-payload" ''
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
    (steps.split "android-platform-tools.finalize")
    (outputs.copyArtifacts { })
    (command "android-platform-tools.metadata" ''
      component="$out/libexec/android-sdk/${final.installedInterface.sdkPath}"
      cp ${final.sourceLayout.packageMetadata} "$component/package.xml"
      cp ${../android-sdk-license.txt} "$component/TVP-SDK-LICENSE.txt"
      mkdir -p "$out/bin"

    '')

    (outputs.hostELF {

      paths = [
        "libexec/android-sdk/${final.installedInterface.sdkPath}"
        "libexec/android-sdk/${final.installedInterface.sdkPath}/lib64"
      ];
      patterns = [ ];
      loader = final.runtime.loader;
      libraries = final.runtime.libraries;
    })
    (command "android-platform-tools.publish" ''
      component="$out/libexec/android-sdk/${final.installedInterface.sdkPath}"
      for tool in adb fastboot etc1tool hprof-conv sqlite3 make_f2fs make_f2fs_casefold mke2fs; do ln -s "$component/$tool" "$out/bin/"; done
    '')
  ];
  tvp.android = {
    sdkPath = final.installedInterface.sdkPath;
    componentPath = "libexec/android-sdk/${final.installedInterface.sdkPath}";
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
