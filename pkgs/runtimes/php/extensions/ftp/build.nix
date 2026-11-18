# Bundled FTP needs an explicit TLS switch when built with phpize.
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
  openssl,
  configureOptions ? [ "--enable-ftp" ],
  patches ? [ ],
  libraries ? [ ],
  loader ? "extension",
  extensionMeta ? { },
  sourceMode ? "archive",
  compression ? "gzip",
}:
final:
let
  # ext/ftp/config.m4 renamed the standalone TLS switch in PHP 8.4.0.
  tlsOption =
    if lib.versionOlder final.php.version "8.4" then "--with-openssl-dir" else "--with-ftp-ssl";
  procedure =
    import ../build-bundled.nix
      (builtins.removeAttrs args [ "openssl" ] // { inherit configureOptions loader; })
      (
        final
        // {
          configureOptions = [ tlsOption ] ++ final.configureOptions;
          libraries = [ final.openssl ] ++ final.libraries;
        }
      );
in
procedure // { inherit openssl; }
