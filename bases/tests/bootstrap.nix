# Each complete compiler is built by an explicit earlier source generation.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  underlyingDriver =
    driver: if driver ? underlyingDriver then underlyingDriver driver.underlyingDriver else driver;
  rows =
    lib.genAttrs
      [
        "gcc_4"
        "gcc_9"
        "gcc_13"
        "gcc_16"
      ]
      (
        name:
        let
          driver = tvp.bases.${name}.full.compiler;
          raw = (underlyingDriver driver).tvp.deps.compiler;
          base = raw.specification.base;
          previous = if base ? compiler then base.compiler else base.stdenv.cc;
        in
        raw ? artifact
        && previous.drvPath != driver.drvPath
        && previous.drvPath != raw.drvPath
        && !(base ? pkgs)
      );
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) rows);
in
assert failed == [ ] || throw "TVP compiler bootstrap cycle: ${lib.concatStringsSep ", " failed}";
pkgs.writeText "tvp-source-bootstrap-independent" (builtins.toJSON rows)
