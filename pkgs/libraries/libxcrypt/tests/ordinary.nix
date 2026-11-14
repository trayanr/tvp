{
  pkgs,
  tvpLib,
  package,
  tvp,
}:
(import ./ordinary-owned.nix {
  inherit
    pkgs
    tvpLib
    package
    tvp
    ;
})
// (import ../../../../lib/tests/command-source-edit.nix { inherit tvp package; })
// (import ../../ordinary-attr-crypt-contracts.nix { inherit tvp package; })
