# pkg-config owns .pc discovery. Provider activation is explicit in tools.
{
  tool,
  libraries,
  directories,
}:
{
  values = {
    PKG_CONFIG = "${tool}/bin/pkg-config";
    PKG_CONFIG_PATH = "";
    PKG_CONFIG_SYSROOT_DIR = "";
  };
  paths.PKG_CONFIG_LIBDIR = {
    separator = ":";
    entries = builtins.concatMap (p: (directories p).pkgconfig) libraries;
  };
}
