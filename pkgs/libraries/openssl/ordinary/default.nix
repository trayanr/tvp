# Definitions split at observed size; no procedure imports a peer procedure.
{ tvp, tvpLib, candidate, constructionTool }:
let
  args = { inherit tvp tvpLib candidate constructionTool; };
in
(import ./0.nix args) // (import ./1.nix args) // (import ./3.nix args) // (import ./4.nix args)
