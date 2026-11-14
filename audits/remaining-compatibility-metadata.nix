# Bounded original metadata and unaffected sibling identities; no graph traversal.
{ root ? ../., pkgs }:
let
  tvp = import root { inherit pkgs; };
  u = import (root + /pkgs) { inherit pkgs tvp; };
  names = [ "acl_2_3_0" "acl_2_3_1" "gawk_3_0_6" "gawk_3_1_8" "gdbm_1_7_3" "gdbm_1_8_1" "gmp_5_0_5" "gmp_5_1_3" "gmp_6_0_0a" "mpfr_2_4_2" "mpfr_3_0_1" "mpfr_3_1_6" "mpc_1_0_3" ];
in {
  metadata = pkgs.lib.genAttrs names (n: let p = tvp.canonical.${n}; in {
    inherit (p) version;
    source = toString p.src;
    hash = u.recipes.${p.pname}.versionTable.${p.version}.sha256;
    inherit (p.meta) description license platforms;
    status = p.tvp.status;
    declaredFeatures = builtins.intersectAttrs (if p.pname == "gmp" then { cxx = null; } else if p.pname == "mpfr" then { float128 = null; mpfrRoundingNames = null; } else if p.pname == "gdbm" then { shared = null; compatLib = null; } else if p.pname == "gawk" then { bignum = null; } else {}) (p.tvp.features or {});
  });
  siblings = pkgs.lib.genAttrs [ "acl_2_3_2" "acl_2_4_0" "gawk_4_0_2" "gdbm_1_8_0" "gmp_6_1_0" "mpfr_4_0_2" "mpc_1_1_0" ] (n: let p = tvp.canonical.${n}; in { drv = p.drvPath; tests = builtins.mapAttrs (_: t: t.drvPath) p.tests; });
}
