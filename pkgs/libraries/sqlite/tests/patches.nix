# Exact existing test-patch order: VFS adapter, then portability records.
{ lib }:
name:
lib.optionals
  (builtins.elem name [
    "3.6.7"
    "3.6.10"
    "3.6.11"
  ])
  [
    {
      file = ../patches/3.6.7-test-async-dlsym.patch;
      reason = "Only src/test_async.c: match VFS xDlSym callback type; upstream fixed this test adapter in 3.6.12.";
    }
  ]
++ (import ./test-portability-patches.nix { inherit lib; }) name
