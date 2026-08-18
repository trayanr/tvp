{ pkgs, tvp }:
tvp.lib.packages.merge {
  "1.0" = import ./0.nix { inherit pkgs tvp; };
  "1.1" = import ./1.nix { inherit pkgs tvp; };
}
