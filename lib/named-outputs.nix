# Internal validation shared by primitive lowering and the fresh-step boundary.
{ lib }:
names:
let
  fail = message: throw "TVP named outputs: ${message}";
  # Lowercase shell identifiers exclude Bash/Nix control variables. Also reserve
  # primitive fields and every constructor/catalogue projection we expose.
  reserved = [
    "auto_resume"
    "histchars"
    "script"
    "status"
    "temporary"
    "attempt"
    "event"
    "all"
    "args"
    "artifact"
    "base"
    "bash"
    "builder"
    "compiler"
    "coreutils"
    "development"
    "drvPath"
    "edit"
    "editRuntime"
    "editSteps"
    "env"
    "environment"
    "environments"
    "meta"
    "name"
    "outPath"
    "outputName"
    "outputs"
    "override"
    "overrideAttrs"
    "passthru"
    "plan"
    "pname"
    "runtime"
    "specification"
    "src"
    "stageInputs"
    "stdenv"
    "system"
    "tests"
    "tvp"
    "type"
    "version"
    "buildEnvironment"
    "buildStepRunner"
    "buildSteps"
    "factory"
    "provenance"
    "outputChecks"
    "passAsFile"
    "preferLocalBuild"
    "allowSubstitutes"
    "structuredAttrs"
  ];
  valid =
    name:
    builtins.isString name
    && !builtins.hasContext name
    && builtins.match "[a-z][a-z0-9_]*" name != null
    && !(builtins.elem name reserved);
in
if !builtins.isList names then
  fail "expected a list"
else if names == [ ] then
  fail "expected a nonempty list including out"
else if !builtins.all valid names then
  fail "unsafe or reserved output name"
else if builtins.length (lib.unique names) != builtins.length names then
  fail "duplicate output name"
else if builtins.head names != "out" then
  fail "out must be the first output"
else
  names
