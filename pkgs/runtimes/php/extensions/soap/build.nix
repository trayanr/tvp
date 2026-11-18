# Select the library inputs for the bundled soap procedure.
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
  libxml2,
  configureOptions ? [ "--enable-soap" ],
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
      (builtins.removeAttrs args [ "libxml2" ] // { inherit configureOptions loader; })
      (
        final
        // {
          libraries = [ final.libxml2 ] ++ final.libxml2.specification.runtime.libraries ++ final.libraries;
        }
      );
in
procedure // { inherit libxml2; }
