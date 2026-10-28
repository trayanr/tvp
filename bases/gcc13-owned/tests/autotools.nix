# New canonical packages use this completed base; they are not inputs to its
# own bootstrap. Keep their end-to-end suites and runtime audit explicit.
{
  pkgs,
  tvp,
}:
let
  packages = {
    automake = tvp.packages.automake_1_19;
    libtool = tvp.packages.libtool_2_6_2;
    flex = tvp.packages.flex_2_6_4;
  };
in
{
  inherit packages;
  tests = pkgs.lib.concatMapAttrs (
    name: package:
    pkgs.lib.mapAttrs' (test: drv: pkgs.lib.nameValuePair "${name}-${test}" drv) package.tests
  ) packages;
  runtimePaths = pkgs.lib.attrValues packages;
}
