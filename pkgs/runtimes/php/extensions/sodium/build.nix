args@{
  tvp,
  lib,
  base,
  src,
  version,
  php,
  extensionName,
  phpCompatibility,
  autoconf,
  automake,
  libtool,
  libsodium,
  configureOptions ? [ "--with-sodium" ],
  patches ? [ ],
  libraries ? [ ],
  loader ? "extension",
  extensionMeta ? { },
  sourceMode ? "archive",
  compression ? "gzip",
}:
final:
import ../build-bundled.nix (builtins.removeAttrs args [ "libsodium" ]) (
  final
  // {
    libraries = [ final.libsodium ] ++ final.libraries;
  }
)
// {
  inherit libsodium;
}
