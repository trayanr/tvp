{
  package,
  lib,
  context,
}:
let
  # Reuse the existing owned constructor implementation for the retained GCC
  # capture protocol. This is test construction, not a production escape hatch.
  tvp.builder = import ../../../../lib/builder.nix { inherit lib; };
  selected = package // {
    testContext = context;
  };
  older = lib.versionOlder package.version "16";
  installed =
    if older then
      import ./native-13.3.0.nix {
        package = selected;
        inherit tvp lib;
      }
    else
      import ./native-16.2.0.nix {
        package = selected;
        inherit tvp lib;
      };
  upstream =
    import (if older then ./checkpoint-upstream-13.3.0.nix else ./checkpoint-upstream-16.2.0.nix)
      {
        inherit package lib context;
      };
in
installed // { upstream-audit = upstream.acceptance; }
