{ pkgs, tvp }:
let
  families = {
    apcu = import ./apcu { inherit pkgs tvp; };
    redis = import ./redis { inherit pkgs tvp; };
    igbinary = import ./igbinary { inherit pkgs tvp; };
    pdo_dblib = import ./pdo_dblib { inherit pkgs tvp; };
  };
  versionTables = builtins.mapAttrs (_: family: family.versionTable) families;
  plain = php: php.unwrapped or php;
  compatible =
    php: entry:
    let
      limits = entry.def.opts.phpCompatibility;
    in
    if limits ? exact then
      php.version == limits.exact
    else
      builtins.compareVersions php.version limits.min >= 0
      && builtins.compareVersions php.version limits.before < 0;
  bindFamily =
    engine: name: family:
    let
      pname = "php-${name}";
      eligible = pkgs.lib.filterAttrs (_: entry: compatible engine entry) family.versionTable;
      bound = builtins.mapAttrs (_: package: package.override { php = engine; }) family.canonical;
      valid = builtins.intersectAttrs (pkgs.lib.genAttrs (map (tvp.lib.versions.attrName pname) (
        builtins.attrNames eligible
      )) (_: null)) bound;
      aliases =
        if eligible == { } then
          { }
        else
          tvp.lib.packages.mkAliases {
            inherit pname;
            versionTable = eligible;
            canonical = valid;
          };
      choices = bound // aliases;
    in
    pkgs.lib.mapAttrs' (
      name: value: pkgs.lib.nameValuePair (pkgs.lib.removePrefix "php-" name) value
    ) choices
    // pkgs.lib.optionalAttrs (eligible == { }) {
      ${name} = throw "PHP ${name}: no declared compatible extension release for PHP ${engine.version}";
    };
  bind =
    php:
    pkgs.lib.foldl' (bound: name: bound // bindFamily (plain php) name families.${name}) { } (
      builtins.attrNames families
    );
in
(tvp.lib.packages.mergeNamespaces families)
// {
  forPHP = bind;
  inherit compatible versionTables;
  redisVersions = versionTables.redis;
}
