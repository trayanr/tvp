# Build the bundled driver against the same PHP source and SDK.
args@{
  tvp,
  lib,
  base,
  src,
  version,
  php,
  freetds,
  extensionName,
  phpCompatibility,
  autoconf,
  automake,
  libtool,
  configureOptions ? [ ],
  libraries ? [ ],
  loader ? "extension",
  extensionMeta ? { },
  sourceMode ? "archive",
  compression ? "gzip",
}:
final:
let
  context = tvp.builder.forBase final.base;
  procedure = import ../build-phpize.nix (builtins.removeAttrs args [ "freetds" ]) (
    final
    // {
      src = final.php.specification.src;
      configureOptions = final.configureOptions ++ [ "--with-pdo-dblib=${final.freetds}" ];
      libraries = [ final.freetds ] ++ final.libraries;
    }
  );
in
procedure
// {
  inherit freetds;
  plan = context.steps.insertAfter "source.unpack" [
    {
      name = "php-pdo_dblib.select-source";
      cwd = "source";
      run = ''
        test -f ext/pdo_dblib/config.m4
        mv ext/pdo_dblib "$TVP_SOURCE_ROOT/pdo_dblib"
        mv "$TVP_SOURCE_ROOT/source" "$TVP_SOURCE_ROOT/php-source"
        mv "$TVP_SOURCE_ROOT/pdo_dblib" "$TVP_SOURCE_ROOT/source"
      '';
    }
  ] procedure.plan;
}
