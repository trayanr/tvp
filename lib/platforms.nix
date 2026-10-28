# Derivation-affecting: loader paths and architecture settings reach build
# commands. Refactoring this interface is neutral only when its values stay so.
{ lib }:
let
  # Platform facts, not package-version policy. Adding an entry is separate
  # from porting and validating the recipes which use it.
  native = {
    x86_64-linux = {
      config = "x86_64-unknown-linux-gnu";
      dynamicLinker = "lib/ld-linux-x86-64.so.2";
      linuxHeadersArch = "x86";
      libcLibdirAliases = [ "lib64" ];
    };
  };
in
rec {
  supportedNativeSystems = lib.attrNames native;

  mkNative =
    {
      buildPlatform,
      hostPlatform,
      targetPlatform,
    }:
    if buildPlatform.config != hostPlatform.config || hostPlatform.config != targetPlatform.config then
      throw "TVP: the native platform interface does not support cross compilation (build ${buildPlatform.config}, host ${hostPlatform.config}, target ${targetPlatform.config})."
    else if !(native ? ${hostPlatform.system}) then
      throw "TVP: unsupported native platform '${hostPlatform.system}'. Supported: ${lib.concatStringsSep ", " supportedNativeSystems}."
    else if hostPlatform.config != native.${hostPlatform.system}.config then
      throw "TVP: unsupported native ABI '${hostPlatform.config}' for '${hostPlatform.system}'; expected '${
        native.${hostPlatform.system}.config
      }'."
    else
      native.${hostPlatform.system}
      // {
        inherit buildPlatform hostPlatform targetPlatform;
        inherit (hostPlatform) system;
        isNative = true;
      };

  forStdenv =
    stdenv:
    mkNative {
      inherit (stdenv) buildPlatform hostPlatform targetPlatform;
    };
}
