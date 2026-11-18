# Select the library inputs for the xdebug procedure.
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
  zlib,
  configureOptions ? [ "--enable-xdebug" ],
  patches ? [ ],
  libraries ? [ ],
  loader ? "zend_extension",
  extensionMeta ? { },
  sourceMode ? "archive",
  compression ? "gzip",
}:
final:
let
  procedure =
    import ../build-phpize.nix
      (builtins.removeAttrs args [ "zlib" ] // { inherit configureOptions loader; })
      (
        final
        // {
          libraries = [ final.zlib ] ++ final.libraries;
        }
      );
in
procedure // { inherit zlib; }
