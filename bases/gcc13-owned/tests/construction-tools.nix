# Historical validation roots follow the pre-owned Zstd recipe. These are test
# inputs only; ordinary public tools continue to follow the canonical package.
{ pkgs, tvp }:
let
  family = (import ../../../pkgs/libraries/zstd { inherit pkgs tvp; }).recipes.zstd;
  zstd = (tvp.lib.packages.mkVersions family.constructionRecipe).zstd_1_5_7;
  file = tvp.packages.file.override { inherit zstd; };
  libtool = tvp.packages.libtool_2_6_2.override { inherit file; };
in
{
  inherit zstd file libtool;
}
