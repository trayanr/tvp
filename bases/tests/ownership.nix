# Declaring ownership adds only the generic runtime closure audit.
{
  pkgs,
  tvpLib,
  base,
}:
{
  runtime-ownership = tvpLib.bases.mkOwnershipTest {
    inherit pkgs base;
    name = "runtime-ownership";
    inherit (base.ownership) roots allowedRuntimePaths;
  };
}
