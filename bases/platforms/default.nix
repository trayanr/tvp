# Resolve the execution platform once, before selecting compiler-family stages.
{ system }:
let
  supported = {
    x86_64-linux = ./x86_64-linux.nix;
  };
in
if builtins.hasAttr system supported then
  import supported.${system}
else
  throw "TVP bases: unsupported system '${system}'; supported: ${builtins.concatStringsSep ", " (builtins.attrNames supported)}"
