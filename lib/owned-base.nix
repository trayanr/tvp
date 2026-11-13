# Pure native base data. Re-enter on replacement so no environment captures an
# earlier compiler. Shell is a package and contributes to PATH before base tools.
# referencePackages records definition ownership without adding execution inputs.
{ lib }:
let
  make =
    args@{
      name,
      platform,
      compiler,
      shell,
      tools,
      referencePackages ? [ ],
      coreutils ? null,
      standardTools ? { },
      construction ? null,
    }:
    let
      fail = message: throw "TVP owned base: ${message}";
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
          platform.system != "x86_64-linux"
          || platform.config != "x86_64-unknown-linux-gnu"
          || platform.isMusl
        then
          fail "only native x86_64 GNU/Linux is supported"
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
        else if !(builtins.isAttrs standardTools) then
          fail "standardTools must be a named package set"
        else if
          builtins.any (name: standardTools ? ${name}) [
            "bash"
            "coreutils"
            "binutils"
          ]
        then
          fail "standard Bash, Coreutils and Binutils come from shell, coreutils and compiler"
        else if !(package shell && builtins.isList tools && builtins.all package tools) then
          fail "shell and baseline tools must be packages"
        else if !(builtins.all matchesExecution ([ shell ] ++ tools)) then
          fail "shell and baseline tools must execute on the native platform"
        else
          true;
      composeEnvironment = import ./build-environment.nix { inherit lib base; };
      base =
        {
          inherit
            name
            platform
            compiler
            shell
            tools
            referencePackages
            ;
          runtimeDirectories = compiler.runtimeDirectories;
          # Validate only selected roles; forcing the whole set would create cycles.
          standardTools = lib.mapAttrs (
            name: tool:
            if package tool && matchesExecution tool then
              tool
            else
              fail "standard tool ${name} must execute on the selected platform"
          ) standardTools;
          environment = composeEnvironment;
          override =
            replacements:
            let
              changes = if builtins.isFunction replacements then replacements args else replacements;
              reboundTools = lib.optionalAttrs (!(changes ? tools)) {
                tools = map (
                  tool:
                  if coreutils != null && changes ? coreutils && tool.outPath == coreutils.outPath then
                    changes.coreutils
                  else if changes ? shell && tool.outPath == shell.outPath then
                    changes.shell
                  else
                    tool
                ) tools;
              };
              reboundStandards = lib.optionalAttrs (changes ? standardTools) {
                standardTools = standardTools // changes.standardTools;
              };
            in
            make (args // reboundTools // changes // reboundStandards);
          # Edits transform the complete selected input record and re-enter all
          # validation/environment binding, just like explicit argument overrides.
          edit =
            transform:
            let
              edited = transform args;
              nextCoreutils = edited.coreutils or null;
              nextShell = edited.shell or shell;
              reboundTools = lib.optionalAttrs ((edited.tools or [ ]) == tools) {
                tools = map (
                  tool:
                  if coreutils != null && nextCoreutils != null && tool.outPath == coreutils.outPath then
                    nextCoreutils
                  else if tool.outPath == shell.outPath then
                    nextShell
                  else
                    tool
                ) tools;
              };
            in
            make (edited // reboundTools);
        }
        // lib.optionalAttrs (coreutils != null) { inherit coreutils; }
        // lib.optionalAttrs (construction != null) { inherit construction; };
    in
    builtins.seq checked base;
in
make
