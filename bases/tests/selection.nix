# Public selections may advance; the generations constructing them stay pinned.
{
  pkgs,
  tvp,
  construction,
}:
let
  inherit (pkgs) lib;
  bases = tvp.bases;
  contracts = {
    active-gcc13 =
      bases.default.name == "gcc13-owned-v3"
      && bases.gcc13-owned.stdenv.drvPath == bases.gcc13-owned-v3.stdenv.drvPath;
    retired-v2 = !(bases ? gcc13-owned-v2);
    no-construction-api = !(tvp ? bootstrap) && !(tvp ? construction) && !(tvp ? recipes);
    retired-public = !(bases ? gcc13) && !(tvp.variants ? gcc13) && !(tvp.variants ? gcc13-owned);
    pinned-parent =
      bases.default.builtBy == "internal:gcc13-owned"
      && construction.bases.gcc13-owned.builtBy == "gcc13";
    pinned-fixup =
      bases.default.fixupTools.patchelf.drvPath
      == construction.variants.gcc13-owned.patchelf_0_19_2.drvPath
      &&
        construction.variants.gcc13-owned.patchelf_0_19_2.stdenv.drvPath
        == construction.bases.gcc13-owned.stdenv.drvPath;
    canonical-tools = lib.all (p: p.tvp.base == bases.default.name) [
      tvp.packages.gcc_13_3_0
      tvp.packages.binutils_2_42
      tvp.packages.glibc_2_39
      tvp.packages.patchelf_0_19_2
    ];
  };
  failed = lib.attrNames (lib.filterAttrs (_: passed: !passed) contracts);
in
if failed != [ ] then
  throw "TVP: base selection contracts failed: ${lib.concatStringsSep ", " failed}"
else
  pkgs.runCommand "tvp-base-selection" { } ''
    printf '%s\n' ${lib.escapeShellArgs (lib.attrNames contracts)} > "$out"
  ''
