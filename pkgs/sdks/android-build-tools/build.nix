# Complete android-build-tools production procedure; released profile facts stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
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
  pname = "android-build-tools";
  inherit
    base
    src
    version
    runtimeLibc
    runtimeCompiler
    unzip
    jdk
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
      (command "android-build-tools.install-payload" ''
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
    (steps.split "android-build-tools.finalize")
    # Nix store optimisation can hardlink the identical SDK linker placeholders.
    # Host ELF repair requires private files in the final output.
    (outputs.copyArtifacts { preserveHardlinks = false; })
    (command "android-build-tools.metadata" ''
      component="$out/libexec/android-sdk/${final.installedInterface.sdkPath}"
      cp ${final.sourceLayout.packageMetadata} "$component/package.xml"
      cp ${../android-sdk-license.txt} "$component/TVP-SDK-LICENSE.txt"
      mkdir -p "$out/bin"
      for script in "$component/apksigner" "$component/d8"; do
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
      paths = [
        "libexec/android-sdk/${final.installedInterface.sdkPath}/apksigner"
        "libexec/android-sdk/${final.installedInterface.sdkPath}/d8"
        "libexec/android-sdk/${final.installedInterface.sdkPath}/lld"
      ];
    })
    (outputs.hostELF {

      paths = [
        "libexec/android-sdk/${final.installedInterface.sdkPath}"
        "libexec/android-sdk/${final.installedInterface.sdkPath}/lib64"
        "libexec/android-sdk/${final.installedInterface.sdkPath}/lld-bin"
      ];
      patterns = [ ];
      loader = final.runtime.loader;
      libraries = final.runtime.libraries;
    })
    (command "android-build-tools.publish" ''
      component="$out/libexec/android-sdk/${final.installedInterface.sdkPath}"
      for tool in aapt aapt2 aidl apksigner d8 dexdump zipalign; do ln -s "$component/$tool" "$out/bin/"; done
    '')
  ];
  tvp.android = {
    sdkPath = final.installedInterface.sdkPath;
    componentPath = "libexec/android-sdk/${final.installedInterface.sdkPath}";
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
