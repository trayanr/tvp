# These checks belong to this base's declared assembly, rather than to the
# generic ownership capability shared with other bases.
{
  pkgs,
  tvpLib,
  base,
}:
{
  gprofng = tvpLib.bases.mkBaseTest {
    inherit base;
    name = "gprofng";
    script = ''
      gprofng display html --help > frontend-help
      gp-display-html --help > direct-help
      grep -Fq 'Usage: gprofng display html' frontend-help
      grep -Fq 'Usage: gprofng display html' direct-help
      echo ok
    '';
    expected = "ok";
  };
  consumers = tvpLib.tests.mkBatch {
    inherit pkgs;
    name = "base-${base.name}-consumers";
    suite = base.consumerTests;
  };
  consumer-runtime-ownership = tvpLib.bases.mkOwnershipTest {
    inherit pkgs base;
    name = "consumer-runtime-ownership";
    roots = pkgs.lib.attrValues base.consumerPackages;
    allowedRuntimePaths =
      base.ownership.allowedRuntimePaths
      ++ pkgs.lib.attrValues base.consumerPackages;
  };
  components = tvpLib.tests.mkBatch {
    inherit pkgs;
    name = "base-${base.name}-components";
    suite =
      let
        c = base.components;
        packages = {
          inherit (c)
            gcc
            binutils
            libc
            perl
            ;
        } // c.floor // c.libraries;
      in
      pkgs.lib.concatMapAttrs (
        name: package:
        pkgs.lib.mapAttrs' (test: drv: pkgs.lib.nameValuePair "${name}-${test}" drv) package.tests
      ) packages;
  };
}
