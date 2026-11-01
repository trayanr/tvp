# Only the installation operations used by TVP's six repository commands.
{
  lib,
  bash,
  coreutils,
  shellcheck,
  platform,
}:
let
  build =
    {
      name,
      command ? name,
      script,
      files,
    }:
    (builtins.derivation {
      inherit name script;
      passAsFile = [ "script" ];
      inherit (platform) system;
      builder = "${bash}/bin/bash";
      args = [
        "-euo"
        "pipefail"
        "-c"
        ''
          export PATH=${lib.escapeShellArg "${coreutils}/bin"}
          mkdir -p "$out/bin" "$out/libexec/${command}"
          cp "$scriptPath" "$out/bin/${command}"
          ${lib.concatStrings (
            lib.mapAttrsToList (file: source: ''
              cp ${lib.escapeShellArg "${source}"} "$out/libexec/${command}/${file}"
            '') files
          )}
          chmod +x "$out/bin/${command}"
          ${bash}/bin/bash -n "$out/bin/${command}"
          ${shellcheck}/bin/shellcheck "$out/bin/${command}"
        ''
      ];
    })
    // {
      meta = {
        mainProgram = command;
        platforms = [ platform.system ];
      };
    };
in
{
  shell =
    {
      name,
      runtimeInputs,
      text,
    }:
    build {
      inherit name;
      files = { };
      script = ''
        #!${bash}/bin/bash
        set -o errexit
        set -o nounset
        set -o pipefail
        export PATH=${lib.escapeShellArg (lib.makeBinPath runtimeInputs)}:"$PATH"
        ${text}
      '';
    };
  python =
    {
      name,
      command ? name,
      python3,
      files,
      entrypoint,
      systemVariable,
    }:
    build {
      inherit name command;
      inherit files;
      script = ''
        #!${bash}/bin/bash
        set -o errexit
        export ${systemVariable}=${lib.escapeShellArg platform.system}
        exec ${python3}/bin/python3 ${builtins.placeholder "out"}/libexec/${command}/${entrypoint} "$@"
      '';
    };
}
