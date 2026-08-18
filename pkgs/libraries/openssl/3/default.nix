{ pkgs, tvp }:
tvp.lib.packages.merge {
  "3.0" = import ./0.nix { inherit pkgs tvp; };
  "3.1" = import ./1.nix { inherit pkgs tvp; };
  "3.2" = import ./2.nix { inherit pkgs tvp; };
  "3.3" = import ./3.nix { inherit pkgs tvp; };
  "3.4" = import ./4.nix { inherit pkgs tvp; };
  "3.5" = import ./5.nix { inherit pkgs tvp; };
  "3.6" = import ./6.nix { inherit pkgs tvp; };
}
