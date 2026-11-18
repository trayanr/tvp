# Select the library inputs for the bundled pdo_odbc procedure.
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
  unixodbc,
  configureOptions ? [ ],
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
      (builtins.removeAttrs args [ "unixodbc" ] // { inherit configureOptions loader; })
      (
        final
        // {
          configureOptions = [ "--with-pdo-odbc=unixODBC,${final.unixodbc}" ] ++ final.configureOptions;
          libraries = [ final.unixodbc ] ++ final.libraries;
        }
      );
in
procedure // { inherit unixodbc; }
