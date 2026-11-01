# Internal native fixture adapter; deliberately not exported by lib/default.nix.
{
  lib,
  base,
  bash,
  coreutils,
}:
{ plan }:
let
  # The only selection point: never render/serialize the editable full plan.
  selected = (import ./build-steps.nix).active plan;
  quote = lib.escapeShellArg;
  reserved =
    key:
    builtins.match "[a-zA-Z_][a-zA-Z0-9_]*" key == null
    ||
      builtins.match "(BASH.*|SHELLOPTS|SHELL|ENV|IFS|PATH|CDPATH|GLOBIGNORE|POSIXLY_CORRECT|TVP_.*|LD_.*)" key
      != null
    || (
      lib.hasPrefix "NIX_" key
      && !(builtins.elem key [
        "NIX_CFLAGS_COMPILE"
        "NIX_CFLAGS_LINK"
        "NIX_LDFLAGS"
      ])
    )
    || builtins.elem key [
      "out"
      "outputs"
      "HOME"
      "TMPDIR"
      "PWD"
      "OLDPWD"
      "SHLVL"
      "BASH_ENV"
      "buildInputs"
      "nativeBuildInputs"
      "initialPath"
      "noDumpEnvVars"
      "preHook"
      "postHook"
    ];
  writeScript =
    name: text:
    builtins.derivation {
      inherit name text;
      inherit (base.platform) system;
      builder = "${bash}/bin/bash";
      args = [
        "-euc"
        ''${coreutils}/bin/cp "$textPath" "$out"''
      ];
      passAsFile = [ "text" ];
      preferLocalBuild = false;
      allowSubstitutes = true;
    };
  render =
    step:
    let
      keys = builtins.attrNames step.env;
      bad = builtins.filter reserved keys;
      # Explicit known-field projection: additional metadata stays lazy.
      scriptText = ''
        set -euo pipefail
        shopt -s inherit_errexit
        set +m
        readonly TVP_SOURCE_ROOT="$1"
        cd -- "$TVP_SOURCE_ROOT"
        nativeBuildInputs=(${lib.concatMapStringsSep " " (p: quote (toString p)) step.tools})
        buildInputs=(${lib.concatMapStringsSep " " (p: quote (toString p)) step.libraries})
        # Input/environment setup hooks intentionally remain underneath the fixture.
        # Neither genericBuild nor phase hooks choose/order the step body.
        noDumpEnvVars=1
        source ${quote "${base.stdenv}/setup"}
        trap - EXIT
        set -euo pipefail
        shopt -s inherit_errexit
        ${lib.concatMapStringsSep "\n" (key: "export ${key}=${quote step.env.${key}}") keys}
        TVP_CWD=${quote step.cwd}
        if [[ "$TVP_CWD" != /* ]]; then TVP_CWD="$TVP_SOURCE_ROOT/$TVP_CWD"; fi
        if [[ ! -d "$TVP_CWD" ]]; then
          printf 'TVP step %s: missing cwd: %s\n' ${quote step.name} "$TVP_CWD" >&2
          exit 72
        fi
        cd -- "$TVP_CWD"
        ${step.run}
      '';
    in
    if bad != [ ] then
      throw "TVP step ${step.name}: reserved or malformed env key: ${lib.concatStringsSep ", " bad}"
    else
      {
        inherit (step) name;
        inherit scriptText;
        script = writeScript "tvp-step-${step.name}.sh" scriptText;
      };
  active = map render selected;
  text = ''
    #!${bash}/bin/bash
    set -euo pipefail
    shopt -s inherit_errexit
    export PATH=${quote "${coreutils}/bin"}
    readonly TVP_BASH=${quote "${bash}/bin/bash"}
    readonly TVP_ENV=${quote "${coreutils}/bin/env"}
    ${builtins.readFile ./build-step-runner.sh}
    ${lib.concatMapStringsSep "\n" (s: "tvp_step ${quote s.name} ${quote s.script}") active}
  '';
in
{
  inherit text;
  childScripts = map (s: s.scriptText) active;
  # Active-only dependency projection, useful for inspection without realizing it.
  inputs = lib.concatMap (s: s.tools ++ s.libraries) selected;
  script = writeScript "tvp-build-step-runner" text;
}
