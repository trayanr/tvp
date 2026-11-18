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
  inherit (tvp.builder.forBase final.base) steps tools;
  procedure = import ./build-phpize.nix (builtins.removeAttrs args [ "linkLibraries" ]) (
    final
    // {
      src = final.php.specification.src;
    }
  );
in
procedure
// {
  inherit linkLibraries;
  environment =
    procedure.environment
    // lib.optionalAttrs (final.linkLibraries != [ ]) {
      # Resolve this provider's shared inputs when configure links a test program.
      overrides.flags.NIX_CFLAGS_LINK = map (
        library: "-Wl,-rpath-link,${lib.getLib library}/lib"
      ) final.linkLibraries;
    };
  plan = steps.insertAfter "source.unpack" [
    {
      name = "php-extension.select-bundled-source";
      cwd = "source";
      tools = [ tools.coreutils ];
      run = ''
        module=${lib.escapeShellArg final.extensionName}
        test -f "ext/$module/config.m4"
        mv "$TVP_SOURCE_ROOT/source" "$TVP_SOURCE_ROOT/php-source"
        mv "$TVP_SOURCE_ROOT/php-source/ext/$module" "$TVP_SOURCE_ROOT/source"
      '';
    }
  ] procedure.plan;
}
