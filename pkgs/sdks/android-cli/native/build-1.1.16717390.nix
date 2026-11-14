# 1.1.16717390: owned binary/data repack with pristine installed payload and final-only host adaptation.
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
  pname = "android-cli";
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
      (command "android-cli.install-payload" ''
        mkdir -p "$out/bin"
        install -m755 ${final.src} "$out/bin/android"
      '')
      // {
        tools = [ final.coreutils ];
      }
    )
    (steps.split "android-cli.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (command "android-cli.metadata" ''
      mkdir -p "$out/share/licenses/android-cli"
      cp ${../../android-sdk-license.txt} "$out/share/licenses/android-cli/SDK-LICENSE.txt"
      mkdir -p "$out/bin"

    '')

    (outputs.hostELF {
      inherit (final) python binutils patchelf;
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
