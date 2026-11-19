# Select the library inputs for the bundled pgsql procedure.
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
  postgresql,
  openssl,
  krb5,
  keyutils,
  configureOptions ? [ ],
  patches ? [ ],
  libraries ? [ ],
  linkLibraries ? [ ],
  loader ? "extension",
  extensionMeta ? { },
  sourceMode ? "archive",
  compression ? "gzip",
}:
final:
let
  procedure =
    import ../build-bundled.nix
      (
        builtins.removeAttrs args [
          "postgresql"
          "openssl"
          "krb5"
          "keyutils"
        ]
        // {
          inherit configureOptions loader;
        }
      )
      (
        final
        // {
          libraries = [ final.postgresql.lib ] ++ final.libraries;
          linkLibraries = [
            final.openssl
            final.krb5
            final.keyutils
          ] ++ final.linkLibraries;
          configureOptions = [ "--with-pgsql=${final.postgresql}" ] ++ final.configureOptions;
        }
      );
in
procedure
// {
  inherit
    postgresql
    openssl
    krb5
    keyutils
    ;
}
