# Complete android-commandline-tools production procedure; released profile facts stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
  androidCli,
  jdk,
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
  pname = "android-commandline-tools";
  inherit
    base
    src
    version
    runtimeLibc
    runtimeCompiler
    unzip
    jdk
    androidCli
    ;
  inherit (tools) bash coreutils;
  sourceLayout = {
    archiveRoot = "cmdline-tools";
    packageMetadata = ./metadata-23.0.xml;
  } // sourceLayout;
  installedInterface = {
    sdkPath = "cmdline-tools/23.0";
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
      (command "android-commandline-tools.install-payload" ''
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
    (steps.split "android-commandline-tools.finalize")
    (outputs.copyArtifacts { })
    (command "android-commandline-tools.metadata" ''
              component="$out/libexec/android-sdk/${final.installedInterface.sdkPath}"
              cp ${final.sourceLayout.packageMetadata} "$component/package.xml"
              cp ${../android-sdk-license.txt} "$component/TVP-SDK-LICENSE.txt"
              mkdir -p "$out/bin"
              rm "$component/bin/android"
              ln -s ${final.androidCli}/bin/android "$component/bin/android"
      for script in "$component"/bin/*; do
                if test -f "$script" && ! test -L "$script" && head -c2 "$script" | grep -q '#!'; then
                  ${tools.sed}/bin/sed -i 's|/bin/ls|ls|g; 2i export JAVA_HOME=${final.jdk}\nexport PATH=${final.jdk}/bin:$PATH' "$script"
                fi
              done

    '')
    (outputs.shebangs {

      names = [
        "sh"
        "bash"
      ];
      interpreter = final.runtime.shell;
      paths = [ "libexec/android-sdk/${final.installedInterface.sdkPath}/bin" ];
    })
    (outputs.hostELF {

      paths = [ "libexec/android-sdk/${final.installedInterface.sdkPath}/bin" ];
      patterns = [ ];
      loader = final.runtime.loader;
      libraries = final.runtime.libraries;
    })
    (command "android-commandline-tools.publish" ''
      component="$out/libexec/android-sdk/${final.installedInterface.sdkPath}"
      for tool in "$component/bin/"*; do if test -x "$tool"; then ln -s "$tool" "$out/bin/"; fi; done
    '')
  ];
  tvp.android = {
    sdkPath = final.installedInterface.sdkPath;
    componentPath = "libexec/android-sdk/${final.installedInterface.sdkPath}";
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
