# Select the library inputs for the bundled intl procedure.
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
  icu,
  configureOptions ? [ "--enable-intl" ],
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
      (builtins.removeAttrs args [ "icu" ] // { inherit configureOptions loader; })
      (
        final
        // {
          libraries = [ final.icu ] ++ final.libraries;
        }
      );
in
procedure // { inherit icu; }
