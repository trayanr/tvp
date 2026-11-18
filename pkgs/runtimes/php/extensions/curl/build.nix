# Select the library inputs for the bundled curl procedure.
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
  curl,
  configureOptions ? [ "--with-curl" ],
  patches ? [ ],
  libraries ? [ ],
  loader ? "extension",
  extensionMeta ? { },
  sourceMode ? "archive",
  compression ? "gzip",
}:
final:
let
  procedure =
    import ../build-bundled.nix
      (builtins.removeAttrs args [ "curl" ] // { inherit configureOptions loader; })
      (
        final
        // {
          # Older PHP cURL configure scripts also link OpenSSL directly.
          libraries = [ final.curl ] ++ final.curl.specification.runtime.libraries ++ final.libraries;
        }
      );
in
procedure // { inherit curl; }
