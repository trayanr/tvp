# Definitions split at observed size; no procedure imports a peer procedure.
{
  tvp,
  tvpLib,
  candidate,
  constructionTool,
}:
let
  args = {
    inherit
      tvp
      tvpLib
      candidate
      constructionTool
      ;
  };
  indexes = map (path: import path args) [
    ./0.nix
    ./1.nix
    ./3.nix
    ./4.nix
  ];
  merge =
    left: right:
    let
      duplicates = builtins.filter (name: builtins.hasAttr name left) (builtins.attrNames right);
    in
    if duplicates != [ ] then
      throw "OpenSSL ordinary definitions: duplicate version start"
    else
      left // right;
in
builtins.foldl' merge { } indexes
