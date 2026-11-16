# Public compiler families for the selected system. Construction handles stay private.
{
  system,
  lib,
  builder,
}:
let
  versions = import ../lib/versions.nix { inherit lib; };
  platform = import ./platforms { inherit system; };
  gcc = {
    "4.9.4" = import ./gcc-4.9.4.nix {
      inherit lib platform;
      inherit builder;
      previous = gcc."16.2.0".full;
    };
    "9.5.0" = import ./gcc-9.5.0.nix {
      inherit lib platform;
      inherit builder;
      previous = gcc."16.2.0".full;
    };
    "13.3.0" = import ./gcc-13.3.0.nix {
      inherit lib platform;
      inherit builder;
    };
    "16.2.0" = import ./gcc-16.2.0.nix {
      inherit lib platform;
      inherit builder;
    };
  };
  canonical = builtins.listToAttrs (
    map (version: {
      name = versions.attrName "gcc" version;
      value = gcc.${version};
    }) (builtins.attrNames gcc)
  );
  aliases = import ./aliases.nix {
    pname = "gcc";
    versions = gcc;
  };
in
canonical
// aliases
// {
  default = aliases.gcc_16.full;
}
