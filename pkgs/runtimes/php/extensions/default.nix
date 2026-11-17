{ pkgs, tvp }:
let
  redis = import ./redis { inherit pkgs tvp; };
  plain = php: php.unwrapped or php;
  compatible =
    php: entry:
    let
      limits = entry.def.opts.phpCompatibility;
    in
    builtins.compareVersions php.version limits.min >= 0
    && builtins.compareVersions php.version limits.before < 0;
  bind =
    php:
    let
      engine = plain php;
      eligible = pkgs.lib.filterAttrs (_: entry: compatible engine entry) redis.versionTable;
      bound = builtins.mapAttrs (_: package: package.override { php = engine; }) redis.canonical;
      valid = builtins.intersectAttrs (pkgs.lib.genAttrs (map (tvp.lib.versions.attrName "php-redis") (
        builtins.attrNames eligible
      )) (_: null)) bound;
      aliases =
        if eligible == { } then
          { }
        else
          tvp.lib.packages.mkAliases {
            pname = "php-redis";
            versionTable = eligible;
            canonical = valid;
          };
      choices = bound // aliases;
    in
    pkgs.lib.mapAttrs' (
      name: value: pkgs.lib.nameValuePair (pkgs.lib.removePrefix "php-" name) value
    ) choices
    // pkgs.lib.optionalAttrs (eligible == { }) {
      redis = throw "PHP Redis: no declared compatible extension release for PHP ${engine.version}";
    };
in
(tvp.lib.packages.mergeNamespaces { inherit redis; })
// {
  forPHP = bind;
  inherit compatible;
  redisVersions = redis.versionTable;
}
