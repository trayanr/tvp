# Internal native fixture adapter; deliberately not exported by lib/default.nix.
let
  template = builtins.readFile ./build-step-runner.sh;
  # The temporary-directory rewrite depends only on the shared shell template.
  temporaryTemplate =
    let
      markers = [
        "local name=$1 script=$2 status"
        "tvp_phase \"$name\" || :"
        ''TMPDIR="''${TMPDIR:-/tmp}"''
        "    tvp_cleanup\n"
      ];
    in
    assert builtins.all (
      marker: builtins.replaceStrings [ marker ] [ "" ] template != template
    ) markers;
    builtins.replaceStrings markers [
      "local name=$1 script=$2 status temporary"
      ''
        tvp_phase "$name" || :
            if temporary=$(mktemp -d "''${TMPDIR:-/tmp}/tvp-step.XXXXXXXXXX"); then
                :
            else
                status=$?
                TVP_FINISHING=1
                tvp_log failure "$name" "$status" || :
                tvp_reraise_cancel
                exit "$status"
            fi
      ''
      ''TMPDIR="$temporary"''
      ''
        tvp_cleanup
        if ! rm -rf -- "$temporary"; then
            printf 'TVP step %s: temporary cleanup failed: %s\n' "$name" "$temporary" >&2 || :
            if (( status == 0 )); then status=74; fi
        fi
      ''
    ] template;
in
{
  lib,
  base,
  bash,
  coreutils,
}:
{
  plan,
  prepareStep ? null,
  temporaryDirectories ? false,
  owned ? false,
  outputs ? [ "out" ],
}:
let
  # The only selection point: never render/serialize the editable full plan.
  activeSteps = (import ./build-steps.nix).active plan;
  selected = if prepareStep == null then activeSteps else map prepareStep activeSteps;
  quote = lib.escapeShellArg;
  outputNames = import ./named-outputs.nix { inherit lib; } outputs;
  multiOutput = outputNames != [ "out" ];
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
        # Keep Bash holding the log descriptors until cp has terminated. GNU
        # coreutils closes them before exiting; a tail-exec races Nix's EOF kill.
        # -e retains copy failures, while the builtin prevents that tail-exec.
        ''
          ${coreutils}/bin/cp "$textPath" "$out"
          exit 0
        ''
      ];
      passAsFile = [ "text" ];
      preferLocalBuild = false;
      allowSubstitutes = true;
    };
  render =
    step:
    let
      keys = builtins.attrNames step.env;
      bad = builtins.filter (key: reserved key || builtins.elem key outputNames) keys;
      # Explicit known-field projection: additional metadata stays lazy.
      scriptText =
        if owned then
          ''
            set -euo pipefail
            shopt -s inherit_errexit
            set +m
            readonly TVP_SOURCE_ROOT="$1"
            cd -- "$TVP_SOURCE_ROOT"
            ${
              lib.optionalString multiOutput ("readonly " + lib.concatStringsSep " " outputNames + "\n")
            }export PATH=${quote (lib.concatMapStringsSep ":" (p: "${lib.getBin p}/bin") step.tools)}
            ${lib.concatMapStringsSep "\n" (key: "export ${key}=${quote step.env.${key}}") keys}
            TVP_CWD=${quote step.cwd}
            if [[ "$TVP_CWD" != /* ]]; then TVP_CWD="$TVP_SOURCE_ROOT/$TVP_CWD"; fi
            if [[ ! -d "$TVP_CWD" ]]; then
              printf 'TVP step %s: missing cwd: %s\n' ${quote step.name} "$TVP_CWD" >&2
              exit 72
            fi
            cd -- "$TVP_CWD"
            ${step.run}
          ''
        else
          ''
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
    else if
      step ? outputSelection
      && !(
        builtins.isString step.outputSelection
        && !(builtins.hasContext step.outputSelection)
        && builtins.elem step.outputSelection outputNames
      )
    then
      throw "TVP step ${step.name}: output selector must name a declared output (${lib.concatStringsSep ", " outputNames})"
    else if
      step ? artifactOutputSelection
      &&
        builtins.sort builtins.lessThan step.artifactOutputSelection
        != builtins.sort builtins.lessThan outputNames
    then
      throw "TVP step ${step.name}: artifact outputs must match the complete declared output list"
    else
      {
        inherit (step) name;
        inherit scriptText;
        script = writeScript "tvp-step-${step.name}.sh" scriptText;
      };
  active = map render selected;
  renderRunner = stepCommand: ''
    #!${bash}/bin/bash
    set -euo pipefail
    shopt -s inherit_errexit
    export PATH=${quote "${coreutils}/bin"}
    readonly TVP_BASH=${quote "${bash}/bin/bash"}
    readonly TVP_ENV=${quote "${coreutils}/bin/env"}
    ${if temporaryDirectories then temporaryTemplate else template}
    ${lib.concatStringsSep "\n" (
      builtins.genList (index: stepCommand index (builtins.elemAt active index)) (builtins.length active)
    )}
    # Close cancellation gaps after the last step and during normal exit.
    TVP_FINISHING=1
    tvp_reraise_cancel
  '';
  # Only named-output runners replace the single-output binding. Keep the shared
  # shell file and all default/split-singleout script bytes unchanged.
  binding = ''out="''${out:-$TVP_SOURCE_ROOT/result}"'';
  bindOutputs =
    originalText:
    if multiOutput then
      assert owned || throw "TVP named outputs: requires the owned runner";
      assert lib.hasInfix binding originalText;
      lib.replaceStrings [ binding ] [
        (lib.concatMapStringsSep " " (name: ''${name}="''${${name}:?missing output ${name}}"'') outputNames)
      ] originalText
    else
      originalText;
  text = bindOutputs (renderRunner (_: s: "tvp_step ${quote s.name} ${quote s.script}"));
  inlineText = bindOutputs (
    renderRunner (index: s: ''tvp_step ${quote s.name} "$TVP_STEP_DIR/${toString index}"'')
  );
  childScripts = map (s: s.scriptText) active;
in
{
  inherit text childScripts;
  scriptAttributes = {
    TVP_STAGE_RUNNER = inlineText;
    TVP_STAGE_SCRIPTS = childScripts;
  };
  command = ''
    TVP_STEP_DIR="$PWD/tvp-stage-scripts"
    ${coreutils}/bin/mkdir -m 0700 "$TVP_STEP_DIR"
    for TVP_STEP_INDEX in "''${!TVP_STAGE_SCRIPTS[@]}"; do
      printf '%s' "''${TVP_STAGE_SCRIPTS[$TVP_STEP_INDEX]}" > "$TVP_STEP_DIR/$TVP_STEP_INDEX"
    done
    printf '%s' "$TVP_STAGE_RUNNER" > "$TVP_STEP_DIR/runner.sh"
    TVP_STEP_DIR="$TVP_STEP_DIR" ${bash}/bin/bash "$TVP_STEP_DIR/runner.sh" "$PWD/workspace"
  '';
  # Active-only dependency projection, useful for inspection without realizing it.
  inputs = lib.concatMap (s: s.tools ++ s.libraries) selected;
  # Fixtures use this standalone form to exercise the runner directly.
  script = writeScript "tvp-build-step-runner" text;
}
