# Select the library inputs for the bundled mbstring procedure.
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
  oniguruma,
  configureOptions ? [
    "--enable-mbstring"
    "--enable-mbregex"
  ],
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
      (builtins.removeAttrs args [ "oniguruma" ] // { inherit configureOptions loader; })
      (
        final
        // {
          libraries = [ final.oniguruma ] ++ final.libraries;
        }
      );
in
procedure // { inherit oniguruma; }
