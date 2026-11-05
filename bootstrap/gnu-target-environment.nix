# Separate opt-in base DATA, never a public base or catalogue replacement.
{
  bootstrap ? import ./. { },
  profile ? import ./gnu-target-profile.nix { inherit bootstrap; },
}:
let
  old = import ./gnu-environment.nix { inherit bootstrap; };
  cc = import ./gnu-target-driver.nix { inherit bootstrap profile; };
  base = old.base // {
    name = "private-capability-gnu-target";
    runtimeDirectories = cc.runtimeDirectories;
    stdenv = old.base.stdenv // {
      inherit cc;
    };
    environment = import ../lib/build-environment.nix {
      inherit (old) lib;
      inherit base;
    };
  };
in
{
  inherit (old) lib bash coreutils;
  inherit cc base;
}
