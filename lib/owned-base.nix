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
        else if !(package shell && builtins.isList tools && builtins.all package tools) then
          fail "shell and baseline tools must be packages"
        else if !(builtins.all matchesExecution ([ shell ] ++ tools)) then
          fail "shell and baseline tools must execute on the native platform"
        else
          true;
      composeEnvironment = import ./build-environment.nix { inherit lib base; };
      base = {
        inherit
          name
          platform
          compiler
          shell
          tools
          referencePackages
          ;
        runtimeDirectories = compiler.runtimeDirectories;
        environment = composeEnvironment;
        override =
          replacements:
          make (args // (if builtins.isFunction replacements then replacements args else replacements));
      };
    in
    builtins.seq checked base;
in
make
