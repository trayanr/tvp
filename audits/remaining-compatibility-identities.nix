{ root ? ../., pkgs }:
let
  tvp = import root { inherit pkgs; };
  universe = import (root + /pkgs) { inherit pkgs tvp; };
  construction = (import (root + /bases) { inherit pkgs tvp; tvpLib = tvp.lib; inherit (universe) recipes; }).construction;
  historical = import (root + /bases/gcc13-owned/inputs/test-public.nix) { inherit pkgs tvp; inherit (universe) recipes; };
  names = [ "gawk_5_2_2" "mpfr_4_2_2" "acl_2_3_2" "gawk_5_3_1" "gdbm_1_26" "gmp_6_3_0" "mpfr_4_2_1" "mpc_1_3_1" ];
  id = p: { drv = p.drvPath; tests = builtins.mapAttrs (_: t: t.drvPath) p.tests; };
in {
  gcc13 = builtins.listToAttrs (map (n: { name = n; value = id construction.variants.gcc13.${n}; }) (builtins.filter (n: builtins.hasAttr n construction.variants.gcc13) names));
  gcc16 = builtins.listToAttrs (map (n: { name = n; value = id construction.variants.gcc16.${n}; }) (builtins.filter (n: builtins.hasAttr n construction.variants.gcc16) names));
  historical = builtins.listToAttrs (map (n: { name = n; value = id historical.public.${n}; }) names);
  privateFactories = builtins.listToAttrs (map (name:
    let family = (builtins.match "([^_]+)_.*" name); p = tvp.canonical.${name}; recipe = universe.recipes.${p.pname}.constructionRecipe; old = (tvp.lib.packages.mkVersions recipe).${name};
    in { inherit name; value = {
      identity = id old;
      dependencies = builtins.mapAttrs (_: d: d.drvPath) old.tvp.declaredDependencies;
      opts = recipe.versionTable.${old.version}.def.opts or {};
      builderHash = builtins.hashFile "sha256" recipe.versionTable.${old.version}.def.builder;
      source = toString old.src;
    }; }
  ) [ "acl_2_3_0" "acl_2_3_1" "gawk_3_0_6" "gawk_3_1_8" "gdbm_1_7_3" "gdbm_1_8_1" "gmp_5_0_5" "gmp_5_1_3" "gmp_6_0_0a" "mpfr_2_4_2" "mpfr_3_0_1" "mpfr_3_1_6" "mpc_1_0_3" ]);
  sources = builtins.listToAttrs (map (n: { name = n; value = toString tvp.canonical.${n}.src; }) [ "acl_2_3_0" "acl_2_3_1" "gawk_3_0_6" "gawk_3_1_8" "gdbm_1_7_3" "gdbm_1_8_1" "gmp_5_0_5" "gmp_5_1_3" "gmp_6_0_0a" "mpfr_2_4_2" "mpfr_3_0_1" "mpfr_3_1_6" "mpc_1_0_3" ]);
}
