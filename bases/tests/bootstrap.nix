# A default-alias move must not move the generation which constructs that base.
{
  pkgs,
  parent,
  owned,
  packages,
}:
let
  inherit (pkgs) lib;
  permittedForeign = [
    parent.stdenv.cc.libc.outPath
    parent.stdenv.cc.libc.bin.outPath
  ];
  failures = lib.filterAttrs (
    _: package:
    package.stdenv.drvPath != parent.stdenv.drvPath
    || package.tvp.base != parent.name
    || package.tvp.variant != parent.name
    || !lib.all (
      dependency:
      if dependency ? tvp then
        dependency.tvp.base == parent.name && (dependency.tvp.variant or null) == parent.name
      else
        lib.elem dependency.outPath permittedForeign
    ) (lib.attrValues (package.tvp.deps or { }))
  ) packages;
in
if failures != { } || owned.builtBy != parent.name then
  throw "TVP: bootstrap generation is not independent of default: ${lib.concatStringsSep ", " (lib.attrNames failures)}"
else
  pkgs.runCommand "tvp-bootstrap-independent" { } ''
    printf '%s\n' ${lib.escapeShellArgs (lib.attrNames packages)} > "$out"
  ''
