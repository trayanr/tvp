# Only the two releases missing the open_temp_exec_file declaration.
{
  lib,
  fetchurl,
  cFlags,
  ...
}@args:
(import ./build-3.0.9.nix (removeAttrs args [ "cFlags" ])).overrideAttrs (_: {
  env.NIX_CFLAGS_COMPILE = lib.concatStringsSep " " cFlags;
})
