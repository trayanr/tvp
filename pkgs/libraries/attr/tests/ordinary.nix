{
  pkgs,
  tvpLib,
  package,
  tvp,
}:
(import ./native-owned.nix { inherit pkgs tvpLib package; })
// (import ../../../../lib/tests/command-source-edit.nix {
  inherit tvp package;
  compression = "gzip";
})
// (import ../../ordinary-attr-crypt-contracts.nix { inherit tvp package; })
