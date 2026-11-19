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
  c-client,
  openssl,
  libxcrypt,
  bundled ? false,
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
  inherit (tvp.builder.forBase final.base) steps;
  sharedLibraries = [
    final.openssl
    final.libxcrypt
  ] ++ final.libraries;
  builderArgs = builtins.removeAttrs args [
    "bundled"
    "c-client"
    "openssl"
    "libxcrypt"
  ];
  effective = final // {
    libraries = [ final.c-client ] ++ sharedLibraries;
    configureOptions = [
      "--with-imap=${final.c-client}"
      "--with-imap-ssl"
      "--without-kerberos"
    ] ++ final.configureOptions;
  };
  procedure = import ../build-phpize.nix builderArgs effective;
  bundledProcedure = import ../build-bundled.nix builderArgs effective;
in
procedure
// {
  inherit
    bundled
    c-client
    openssl
    libxcrypt
    configureOptions
    libraries
    ;
  runtime.libraries = sharedLibraries;
  plan = steps.insertBefore "php-extension.phpize" [
    (steps.command { environment.tools = [ final.php ]; } "php-extension.check-non-zts" ''
      if ! ${final.php}/bin/php -n -r 'exit(PHP_ZTS ? 1 : 0);'; then
        echo "IMAP and c-client require a non-ZTS PHP engine" >&2
        exit 1
      fi
    '')
  ] (if final.bundled then bundledProcedure.plan else procedure.plan);
}
