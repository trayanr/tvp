# Exact beta DEPS seed 3.13.0-103.1.beta: pristine binary SDK artifact, host runtime adaptation after copy.
{
  tvp,
  lib,
  base,
  src,
  version,
  channel,
  bash,
  coreutils,
  gawk,
  helperPython,
  binutils,
  patchelf,
  findutils,
  sed,
  grep,
  diffutils,
  unzip,
  runtimeLibc,
  runtimeCompiler,
}:
final:
let
  inherit (tvp.builder) steps outputs;
in
{
  pname = "dart-bootstrap";
  inherit
    base
    src
    version
    channel
    bash
    coreutils
    gawk
    helperPython
    binutils
    patchelf
    findutils
    sed
    grep
    diffutils
    unzip
    runtimeLibc
    runtimeCompiler
    ;
  runtime = {
    loader = "${final.runtimeLibc}/lib/ld-linux-x86-64.so.2";
    libraries = [
      final.runtimeLibc
      final.runtimeCompiler
    ];
  };
  environment = {
    tools = [
      final.coreutils
      final.unzip
    ];
    libraries = [ ];
  };
  plan =
    assert final.channel == "beta" || throw "Beta seed procedure requires the beta channel";
    steps.sequence [
      (
        (final.base.environment final.environment)
        // {
          name = "dart-bootstrap.install-pristine";
          run = ''
            mkdir source
            ${final.unzip}/bin/unzip -q ${lib.escapeShellArg (toString final.src)} -d source
            test -d source/dart-sdk
            mkdir "$out"
            cp -a source/dart-sdk/. "$out/"
          '';
        }
      )
      (steps.split "dart-bootstrap.finalize")
      (outputs.copyArtifacts { inherit (final) coreutils; })
      (outputs.hostELF {
        python = final.helperPython;
        inherit (final) binutils patchelf;
        paths = [
          "bin"
          "bin/utils"
        ];
        patterns = [ ];
        inherit (final.runtime) loader libraries;
      })

    ];
  tvp.dynamicLinker = final.runtime.loader;
  tvp.targetRuntime = final.runtime.libraries;
  meta = {
    description = "Explicit upstream Dart bootstrap SDK distribution";
    homepage = "https://dart.dev/";
    license = lib.licenses.bsd3;
    sourceProvenance = [
      lib.sourceTypes.binaryNativeCode
      lib.sourceTypes.binaryBytecode
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "dart";
  };
}
