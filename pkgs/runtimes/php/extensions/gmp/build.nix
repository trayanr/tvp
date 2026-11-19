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
  gmp,
  configureOptions ? [ ],
  patches ? [ ],
  libraries ? [ ],
  loader ? "extension",
  extensionMeta ? { },
  sourceMode ? "archive",
  compression ? "gzip",
}:
final:
import ../build-bundled.nix (builtins.removeAttrs args [ "gmp" ]) (
  final
  // {
    configureOptions = final.configureOptions ++ [ "--with-gmp=${final.gmp}" ];
    libraries = [ final.gmp ] ++ final.libraries;
  }
)
// {
  inherit gmp;
}
