{ pkgs, tvp }:
let
  families = {
    apcu = import ./apcu { inherit pkgs tvp; };
    bcmath = import ./bcmath { inherit pkgs tvp; };
    calendar = import ./calendar { inherit pkgs tvp; };
    curl = import ./curl { inherit pkgs tvp; };
    exif = import ./exif { inherit pkgs tvp; };
    ftp = import ./ftp { inherit pkgs tvp; };
    gd = import ./gd { inherit pkgs tvp; };
    gettext = import ./gettext { inherit pkgs tvp; };
    gmp = import ./gmp { inherit pkgs tvp; };
    imap = import ./imap { inherit pkgs tvp; };
    intl = import ./intl { inherit pkgs tvp; };
    ldap = import ./ldap { inherit pkgs tvp; };
    mbstring = import ./mbstring { inherit pkgs tvp; };
    opcache = import ./opcache { inherit pkgs tvp; };
    redis = import ./redis { inherit pkgs tvp; };
    igbinary = import ./igbinary { inherit pkgs tvp; };
    mongodb = import ./mongodb { inherit pkgs tvp; };
    pcntl = import ./pcntl { inherit pkgs tvp; };
    pdo_dblib = import ./pdo_dblib { inherit pkgs tvp; };
    pdo_odbc = import ./pdo_odbc { inherit pkgs tvp; };
    pdo_pgsql = import ./pdo_pgsql { inherit pkgs tvp; };
    pgsql = import ./pgsql { inherit pkgs tvp; };
    soap = import ./soap { inherit pkgs tvp; };
    sockets = import ./sockets { inherit pkgs tvp; };
    sodium = import ./sodium { inherit pkgs tvp; };
    sysvsem = import ./sysvsem { inherit pkgs tvp; };
    xdebug = import ./xdebug { inherit pkgs tvp; };
    zip = import ./zip { inherit pkgs tvp; };
    mysqlnd = import ./mysql {
      inherit pkgs tvp;
      name = "mysqlnd";
    };
    mysqli = import ./mysql {
      inherit pkgs tvp;
      name = "mysqli";
    };
    pdo_mysql = import ./mysql {
      inherit pkgs tvp;
      name = "pdo_mysql";
    };
  };
  versionTables = builtins.mapAttrs (_: family: family.versionTable) families;
  phpPolicies = builtins.mapAttrs (
    name: family: family.recipes."php-${name}".packageMeta.phpPolicy
  ) families;
  builtIn = php: name: tvp.lib.php.compatibility.isBuiltIn phpPolicies.${name} php.version;
  plain = php: php.unwrapped or php;
  compatible =
    php: entry:
    let
      limits = entry.def.opts.phpCompatibility;
    in
    tvp.lib.php.compatibility.matches limits php.version;
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
      ${name} =
        if builtIn engine name then
          throw "PHP ${name}: PHP ${engine.version} already includes this extension in the engine"
        else
          throw "PHP ${name}: no declared compatible extension release for PHP ${engine.version}";
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
  runtimeModules =
    php: package:
    let
      available = bind php;
    in
    map (name: available.${name}) (families.${package.extensionName}.requires or [ ]) ++ [ package ];
  inherit
    builtIn
    compatible
    versionTables
    phpPolicies
    ;
  redisVersions = versionTables.redis;
}
