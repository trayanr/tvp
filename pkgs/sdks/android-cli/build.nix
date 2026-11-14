# Complete android-cli production procedure; released profile facts stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
  runtimeCompiler,
  runtimeLibc,
  sourceLayout ? { },
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
  pname = "android-cli";
  inherit
    base
    src
    version
    runtimeLibc
    runtimeCompiler
    ;
  inherit (tools) bash coreutils;
  sourceLayout = { } // sourceLayout;
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
      (command "android-cli.install-payload" ''
        mkdir -p "$out/bin"
        install -m755 ${final.src} "$out/bin/android"
      '')
      // {
        tools = [ final.coreutils ];
      }
    )
    (steps.split "android-cli.finalize")
    (outputs.copyArtifacts { })
    (command "android-cli.metadata" ''
      mkdir -p "$out/share/licenses/android-cli"
      cp ${../android-sdk-license.txt} "$out/share/licenses/android-cli/SDK-LICENSE.txt"
      mkdir -p "$out/bin"

    '')

    (outputs.hostELF {

      paths = [ "bin" ];
      patterns = [ ];
      loader = final.runtime.loader;
      libraries = final.runtime.libraries;
    })
    (command "android-cli.publish" ''

      test -s "$out/bin/android"
    '')
  ];

  meta = {
    description = "Pinned native Android CLI without the auto-downloading launcher";
    homepage = "https://developer.android.com/tools/agents/android-cli";
    mainProgram = "android";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
