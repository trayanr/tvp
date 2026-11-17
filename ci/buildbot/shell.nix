# CI infrastructure is borrowed from the repository's pinned Nixpkgs input.
let
  # Import only the pinned infrastructure input. Deployment roots may be symlinks.
  lock = builtins.fromJSON (builtins.readFile ../../flake.lock);
  nixpkgsNode = lock.nodes.${lock.root}.inputs.nixpkgs;
  nixpkgs = builtins.fetchTree lock.nodes.${nixpkgsNode}.locked;
  pkgs = import nixpkgs.outPath { system = builtins.currentSystem; };
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
    pkgs.python3
  ];
}
