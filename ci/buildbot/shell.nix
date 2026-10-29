# CI infrastructure is borrowed from the repository's pinned Nixpkgs input.
let
  flake = builtins.getFlake (toString ../..);
  pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; };
in
pkgs.mkShell {
  packages = [
    pkgs.buildbot
    pkgs.python3Packages.treq
    pkgs.buildbot-plugins.www
    pkgs.buildbot-plugins.waterfall-view
    pkgs.buildbot-plugins.console-view
    pkgs.buildbot-plugins.grid-view
    pkgs.buildbot-worker
    pkgs.git
    pkgs.cacert
    pkgs.nix
    pkgs.python3
  ];
}
