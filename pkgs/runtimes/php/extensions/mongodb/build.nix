# Select the library inputs for the mongodb procedure.
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
  zlib,
  configureOptions ? [
    "--enable-mongodb"
    "--with-mongodb-system-libs=no"
    "--with-mongodb-ssl=openssl"
    "--with-mongodb-zlib=system"
    "--with-mongodb-snappy=no"
    "--with-mongodb-zstd=no"
    "--with-mongodb-sasl=no"
    "--with-mongodb-client-side-encryption=no"
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
    import ../build-phpize.nix
      (
        builtins.removeAttrs args [
          "openssl"
          "zlib"
        ]
        // {
          inherit configureOptions loader;
        }
      )
      (
        final
        // {
          libraries = [
            final.openssl
            final.zlib
          ]
          ++ final.libraries;
        }
      );
in
procedure // { inherit openssl zlib; }
