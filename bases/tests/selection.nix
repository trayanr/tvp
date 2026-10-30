# Public selections may advance; the generations constructing them stay pinned.
{
  pkgs,
  tvp,
  construction,
}:
let
  inherit (pkgs) lib;
  bases = tvp.bases;
  parent16 = construction.bases.gcc13-owned-v3;
  inputs16 = lib.attrValues construction.variants.gcc16;
  constructionPaths16 = lib.concatMap (p: map (output: toString p.${output}) p.outputs) inputs16 ++ [
    (toString parent16.stdenv.cc.libc)
    (toString parent16.stdenv.cc.libc.bin)
  ];
  contracts = {
    active-gcc16 =
      bases.default.name == "gcc16-owned"
      && bases.gcc16.stdenv.drvPath == bases.gcc16-owned.stdenv.drvPath;
    retired-v2 = !(bases ? gcc13-owned-v2) && !(bases ? gcc13-owned);
    measured-compat =
      bases.gcc13-owned-v3.stdenv.drvPath == construction.bases.gcc13-owned-v3.stdenv.drvPath
      && tvp.packages.acl_2_3_0.tvp.base == "gcc13-owned-v3"
      && tvp.packages.acl_2_3_1.tvp.base == "gcc13-owned-v3"
      && tvp.packages.acl_2_3_2.tvp.base == bases.default.name;
    no-construction-api = !(tvp ? bootstrap) && !(tvp ? construction) && !(tvp ? recipes);
    retired-public = !(bases ? gcc13) && !(tvp.variants ? gcc13) && !(tvp.variants ? gcc13-owned);
    pinned-gcc16-inputs =
      builtins.length inputs16 == 18
      && construction.variants.gcc16.gcc_16_2_0.tvp.bootstrap
      && lib.all (
        p:
        p.tvp.base == parent16.name
        && p.tvp.variant == "gcc16"
        && p.stdenv.drvPath == parent16.stdenv.drvPath
        && lib.all (dep: builtins.elem (toString dep) constructionPaths16) (
          lib.attrValues (p.tvp.deps or { })
        )
      ) inputs16;
    pinned-parent =
      bases.default.builtBy == "internal:gcc13-owned-v3"
      && construction.bases.gcc13-owned.builtBy == "gcc13";
    pinned-fixup =
      bases.default.fixupTools.patchelf.drvPath
      == construction.variants.gcc13-owned.patchelf_0_19_2.drvPath
      &&
        construction.variants.gcc13-owned.patchelf_0_19_2.stdenv.drvPath
        == construction.bases.gcc13-owned.stdenv.drvPath;
    canonical-tools = lib.all (p: p.tvp.base == bases.default.name) [
      tvp.packages.gcc_16_2_0
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
