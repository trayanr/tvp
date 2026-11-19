# Complete dart-bootstrap production procedure; released profile facts stay explicit.
{
  tvp,
  lib,
  base,
  src,
  version,
  gawk,
  runtimeCompiler,
  runtimeLibc,
  unzip,
  sourceLayout ? { },
  buildFeatures ? { },
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
in
{
  pname = "dart-bootstrap";
  inherit
    base
    src
    version
    gawk
    unzip
    runtimeLibc
    runtimeCompiler
    ;
  inherit (tools) bash coreutils;
  sourceLayout = {
    channel = "stable";
  }
  // sourceLayout;
  buildFeatures = {
    startupSmoke = true;
  }
  // buildFeatures;
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
    assert
      builtins.elem final.sourceLayout.channel [
        "beta"
        "stable"
      ]
      || throw "Unsupported upstream binary Dart SDK channel";
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
      (outputs.copyArtifacts { })
      (outputs.hostELF {

        paths = [
          "bin"
          "bin/utils"
        ];
        patterns = [ ];
        inherit (final.runtime) loader libraries;
      })
      {
        name = "dart-bootstrap.startup";
        enabled = final.buildFeatures.startupSmoke;
        tools = [ final.coreutils ];
        run = ''
          export DART_SUPPRESS_ANALYTICS=true XDG_CONFIG_HOME="$PWD/config" PUB_CACHE="$PWD/pub-cache"
          "$out/bin/dart" --version
          "$out/bin/dart" pub --help > pub-help
          test -s pub-help
        '';
      }
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
