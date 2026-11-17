# One lazy provider catalogue. Compatibility aliases are derived, never selected
# independently. Only baselineTools and tools used by steps enter execution inputs.
{ lib }:
let
  fail = message: throw "TVP owned base: ${message}";
  sameProvider =
    a: b:
    builtins.isAttrs a && builtins.isAttrs b && a ? outPath && b ? outPath && a.outPath == b.outPath;
  aliases = {
    compiler = "gcc";
    shell = "bash";
    coreutils = "coreutils";
  };
  mergeAliases =
    arguments: tools:
    builtins.foldl' (
      selected: alias:
      let
        role = aliases.${alias};
      in
      if !(arguments ? ${alias}) then
        selected
      else if selected ? ${role} && !sameProvider selected.${role} arguments.${alias} then
        fail "conflicting ${alias} and tools.${role} selections"
      else
        selected // { ${role} = arguments.${alias}; }
    ) tools (builtins.attrNames aliases);
  reserved = [
    "gcc"
    "bash"
    "coreutils"
    "binutils"
  ];
  make =
    args@{
      name,
      platform,
      tools,
      baselineTools ? [ ],
      referencePackages ? [ ],
      construction ? null,
    }:
    let
      supportedPlatform = import ../bases/platforms { inherit (platform) system; };
      compiler = tools.gcc or (fail "tools.gcc must select a compiler driver");
      shell = tools.bash or (fail "tools.bash must select the execution shell");
      coreutils = tools.coreutils or null;
      selectedBinutils = tools.binutils or compiler.bintools;
      package = p: builtins.isAttrs p && p ? outPath;
      matchesExecution =
        p:
        (p.system or platform.system) == platform.system
        && (
          !(p ? hostPlatform)
          || (
            (p.hostPlatform.system or platform.system) == platform.system
            && (p.hostPlatform.config or platform.config) == platform.config
          )
        );
      matches =
        p:
        matchesExecution p
        && (
          !(p ? targetPlatform)
          || (
            (p.targetPlatform.system or platform.system) == platform.system
            && (p.targetPlatform.config or platform.config) == platform.config
          )
        );
      checked =
        if name == "" then
          fail "name must be nonempty"
        else if
          construction != null
          && !(
            builtins.isAttrs construction
            && builtins.elem (construction.kind or null) [
              "seed"
              "stage"
              "legacy-inputs"
            ]
            &&
              lib.subtractLists [
                "kind"
                "previous"
                "sourceBase"
              ] (builtins.attrNames construction) == [ ]
            &&
              builtins.all
                (
                  key:
                  let
                    value = construction.${key} or null;
                  in
                  value == null || (builtins.isString value && value != "" && !(builtins.hasContext value))
                )
                [
                  "previous"
                  "sourceBase"
                ]
            && (construction.previous or null) != name
            && (construction.kind == "stage" -> (construction.previous or null) != null)
            && (construction.kind == "seed" -> (construction.previous or null) == null)
          )
        then
          fail "construction must identify a seed or an earlier named tier"
        else if
          platform.config != supportedPlatform.config || platform.isMusl != supportedPlatform.isMusl
        then
          fail "platform facts disagree with the selected supported system"
        else if
          !(
            package compiler
            && compiler ? bintools
            && compiler ? libc
            && compiler ? runtimeDirectories
            && compiler ? defaultHardeningFlags
          )
        then
          fail "compiler must declare Binutils, libc, runtimeDirectories and hardening"
        else if
          !(
            builtins.isList compiler.defaultHardeningFlags
            && builtins.all builtins.isString compiler.defaultHardeningFlags
          )
        then
          fail "compiler defaultHardeningFlags must be a list of strings"
        else if !(package compiler.bintools && package compiler.libc) then
          fail "compiler Binutils and libc must be selected packages"
        else if
          !(builtins.all matches [
            compiler
            compiler.bintools
            compiler.libc
          ])
        then
          fail "compiler, Binutils and libc must match the native platform"
        else if
          !(
            builtins.isList compiler.runtimeDirectories
            && compiler.runtimeDirectories != [ ]
            && builtins.all (
              p: builtins.isString p && builtins.hasContext p && lib.hasPrefix "/nix/store/" p
            ) compiler.runtimeDirectories
          )
        then
          fail "compiler must declare nonempty runtimeDirectories"
        else if coreutils != null && !(package coreutils && matchesExecution coreutils) then
          fail "Coreutils must execute on the selected platform"
        else if !(package shell && builtins.isList baselineTools && builtins.all package baselineTools) then
          fail "shell and baseline tools must be packages"
        else if !(builtins.all matchesExecution ([ shell ] ++ baselineTools)) then
          fail "shell and baseline tools must execute on the native platform"
        else if !sameProvider selectedBinutils compiler.bintools then
          fail "tools.binutils disagrees with tools.gcc; select a driver bound to the desired Binutils"
        else
          true;
      composeEnvironment = import ./build-environment.nix { inherit lib base; };
      # Map validation stays lazy: asking for one tool cannot force another role.
      catalogue = lib.mapAttrs (
        role: tool:
        if package tool && matchesExecution tool then
          tool
        else
          fail "tool ${role} must execute on the selected platform"
      ) (tools // { binutils = selectedBinutils; });
      # Preserve explicitly selected provider metadata across no-op edits. The
      # update path drops only an inherited Binutils role when its driver changes.
      inputs = args;
      replace =
        editing: changes:
        let
          legacyTools = builtins.isList (changes.tools or { });
          named = changes.standardTools or { };
          toolChanges = if legacyTools then { } else changes.tools or { };
          aliased = mergeAliases changes (named // toolChanges);
          mergedTools = (if editing && !legacyTools then { } else inputs.tools) // aliased;
          nextCompiler = mergedTools.gcc;
          inheritedBinutils =
            !(toolChanges ? binutils)
            || (editing && sameProvider (toolChanges.binutils or null) (tools.binutils or compiler.bintools));
          nextTools =
            if !sameProvider compiler nextCompiler && inheritedBinutils then
              builtins.removeAttrs mergedTools [ "binutils" ]
            else
              mergedTools;
          nextShell = nextTools.bash;
          nextCoreutils = nextTools.coreutils or null;
          rebound = map (
            tool:
            if
              coreutils != null
              && nextCoreutils != null
              && !sameProvider coreutils nextCoreutils
              && sameProvider tool coreutils
            then
              nextCoreutils
            else if !sameProvider shell nextShell && sameProvider tool shell then
              nextShell
            else
              tool
          ) baselineTools;
          nextBaseline = if legacyTools then changes.tools else changes.baselineTools or rebound;
          extra = builtins.removeAttrs changes [
            "tools"
            "standardTools"
            "compiler"
            "shell"
            "coreutils"
            "libc"
            "binutils"
          ];
          checkedChanges =
            if editing && (!(changes ? name) || !(changes ? platform)) then
              fail "an edit must retain name and platform"
            else if !(mergedTools ? gcc && mergedTools ? bash) then
              fail "an edit must retain tools.gcc and tools.bash"
            else if !builtins.isAttrs named || builtins.any (role: named ? ${role}) reserved then
              fail "standardTools is a compatibility catalogue; select reserved roles through tools"
            else if changes ? libc && !sameProvider changes.libc nextCompiler.libc then
              fail "libc disagrees with tools.gcc; select a driver bound to the desired libc"
            else if changes ? binutils && !sameProvider changes.binutils nextCompiler.bintools then
              fail "binutils disagrees with tools.gcc; select a driver bound to the desired Binutils"
            else
              true;
        in
        builtins.seq checkedChanges (
          make (
            (if editing then { } else inputs)
            // extra
            // {
              tools = nextTools;
              baselineTools = nextBaseline;
            }
          )
        );
      base =
        {
          inherit
            name
            platform
            compiler
            shell
            referencePackages
            ;
          inherit baselineTools;
          tools = catalogue;
          libc = compiler.libc;
          runtimeDirectories = compiler.runtimeDirectories;
          # Temporary compatibility for retained helpers; no second provider record.
          standardTools = builtins.removeAttrs catalogue reserved;
          environment = composeEnvironment;
          override =
            replacements:
            replace false (if builtins.isFunction replacements then replacements inputs else replacements);
          edit = transform: makeEdited (transform inputs);
        }
        // lib.optionalAttrs (coreutils != null) { inherit coreutils; }
        // lib.optionalAttrs (construction != null) { inherit construction; };
      makeEdited =
        edited:
        let
          # Legacy aliases explicitly added by an edit take precedence over the
          # unchanged inherited role. Conflicting new choices still fail closed.
          changes = builtins.foldl' (
            result: alias:
            let
              role = aliases.${alias};
            in
            if
              edited ? ${alias} && sameProvider (edited.tools.${role} or null) (inputs.tools.${role} or null)
            then
              result
              // {
                tools = (result.tools or { }) // {
                  ${role} = edited.${alias};
                };
              }
            else
              result
          ) edited (builtins.attrNames aliases);
          reboundChanges =
            if !(edited ? baselineTools) then
              changes // { baselineTools = [ ]; }
            else if edited.baselineTools == baselineTools then
              builtins.removeAttrs changes [ "baselineTools" ]
            else
              changes;
        in
        replace true reboundChanges;
    in
    builtins.seq checked base;
  # Translate the old constructor shape at one boundary. New definitions use a
  # tools record; legacy tools lists remain exact baseline execution inputs.
  fromArguments =
    args:
    let
      legacyTools = builtins.isList (args.tools or { });
      named = args.standardTools or { };
      tools = named // (if legacyTools then { } else args.tools or { });
      selected = mergeAliases args tools;
      pure = builtins.removeAttrs args [
        "compiler"
        "shell"
        "coreutils"
        "standardTools"
        "tools"
        "baselineTools"
      ];
    in
    if !builtins.isAttrs named || builtins.any (role: named ? ${role}) reserved then
      fail "standardTools cannot select GCC, Bash, Coreutils or Binutils"
    else
      make (
        pure
        // {
          tools = selected;
          baselineTools = if legacyTools then args.tools else args.baselineTools or [ ];
        }
      );
in
fromArguments
