# Select the library inputs for the bundled zip procedure.
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
  libzip,
  configureOptions ? [ "--with-zip" ],
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
      (builtins.removeAttrs args [ "libzip" ] // { inherit configureOptions loader; })
      (
        final
        // {
          libraries = [ final.libzip ] ++ final.libraries;
        }
      );
in
procedure // { inherit libzip; }
