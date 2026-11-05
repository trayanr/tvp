# Explicit pure helper surface for the owned builder. No package set or I/O.
{ system }:
let
  early = (import ./adapter.nix { inherit system; }).lib;
in
rec {
  inherit (early)
    concatStringsSep
    concatMapStringsSep
    optional
    optionalString
    replaceStrings
    ;
  inherit (builtins) concatMap mapAttrs;
  optionalAttrs = condition: value: if condition then value else { };
  fix =
    f:
    let
      result = f result;
    in
    result;
  unique = builtins.foldl' (acc: x: if builtins.elem x acc then acc else acc ++ [ x ]) [ ];
  subtractLists = remove: builtins.filter (x: !(builtins.elem x remove));
  intersectLists = left: builtins.filter (x: builtins.elem x left);
  genAttrs =
    names: f:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = f name;
      }) names
    );
  hasPrefix = prefix: value: builtins.substring 0 (builtins.stringLength prefix) value == prefix;
  hasInfix = infix: value: infix == "" || builtins.replaceStrings [ infix ] [ "" ] value != value;
  escapeShellArg = value: "'" + builtins.replaceStrings [ "'" ] [ "'\\''" ] (toString value) + "'";
  escapeShellArgs = values: concatStringsSep " " (map escapeShellArg values);
  # Metadata only, from the same small attributed pure adapter.
  inherit (early) licenses;
  getOutput = name: p: if p ? ${name} then p.${name} else p;
  getBin = getOutput "bin";
  getDev = getOutput "dev";
  getLib = getOutput "lib";
}
