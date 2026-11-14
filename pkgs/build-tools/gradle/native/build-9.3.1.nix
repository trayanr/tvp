# Own installation/launching of the unchanged upstream binary distribution.
# Bundled bytecode and native payloads are copied without stripping or rewriting.
{
  lib,
  tvp,
  base,
  src,
  version,
  bash,
  coreutils,
  jdk,
  python,
  helperPython,
  unzip,
}@args:
final:
let
  inherit (final)
    base
    src
    version
    bash
    coreutils
    python
    helperPython
    ;
  inherit (tvp.builder) steps outputs;
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      name = "gradle.${name}";
      inherit run;
    };
in
{
  pname = "gradle";
  inherit (args)
    base
    src
    version
    bash
    coreutils
    python
    helperPython
    ;
  seedTemplate = ./seed-wrapper.py;
  environment.tools = [
    unzip
    helperPython
  ];
  runtime = {
    inherit jdk python coreutils;
    shell = bash;
    libraries = [ ];
  };
  buildEnvironment =
    { tool, ... }:
    {
      values.GRADLE_HOME = "${tool}/libexec/gradle";
    };
  passthru = output: {
    distributionArchive = "${output}/share/gradle/gradle-${final.version}-all.zip";
  };
  artifactPlan = steps.sequence [
    (command "unpack" ''
      ${unzip}/bin/unzip -q ${final.src} -d unpacked
      mkdir -p "$out/libexec/gradle" "$out/bin" "$out/nix-support" "$out/share/gradle"
      cp -a unpacked/gradle-${final.version}/. "$out/libexec/gradle/"
      cp ${final.src} "$out/share/gradle/gradle-${final.version}-all.zip"
    '')
  ];
  plan = steps.sequence (
    final.artifactPlan
    ++ [
      (steps.split "gradle.finalize")
      (outputs.copyArtifacts { coreutils = final.coreutils; })
      (command "launchers" ''
        ${helperPython}/bin/python3 -B ${./render.py} "$out" ${
          lib.escapeShellArgs [
            (toString final.runtime.shell)
            (toString final.runtime.jdk)
            (toString final.runtime.coreutils)
            (toString final.runtime.python)
            final.version
            "${final.seedTemplate}"
          ]
        }
        chmod +x "$out/bin/"*
      '')
      (outputs.shebangs {
        python = helperPython;
        paths = [ "libexec/gradle/bin/gradle" ];
        names = [ "sh" ];
        interpreter = "${final.runtime.shell}/bin/bash";
      })
    ]
  );
  meta = {
    description = "Pinned Gradle build tool with owned Java runtime and offline wrapper seed";
    homepage = "https://gradle.org/";
    license = lib.licenses.asl20;
    sourceProvenance = [
      lib.sourceTypes.binaryBytecode
      lib.sourceTypes.binaryNativeCode
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "gradle";
  };
}
