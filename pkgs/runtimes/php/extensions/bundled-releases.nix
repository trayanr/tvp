# Match the bundled source and SDK to the same PHP release.
{
  pkgs,
  tvp,
  minPHP,
  beforePHP ? null,
  def,
}:
let
  phpFamily = (import ../. { inherit pkgs tvp; }).recipes.php;
  releases = pkgs.lib.filterAttrs (
    version: _:
    pkgs.lib.versionAtLeast version minPHP
    && (beforePHP == null || pkgs.lib.versionOlder version beforePHP)
  ) phpFamily.versionTable;
in
{
  inherit (phpFamily) source;
  versionTable = tvp.lib.packages.mkTable (
    pkgs.lib.mapAttrsToList (
      version: release:
      let
        definition = if builtins.isFunction def then def release else def;
      in
      {
        def = definition // {
          # A mixed family may give its standalone releases a different source.
          source = definition.source or phpFamily.source;
          deps = (definition.deps or { }) // {
            php = tvp.lib.packages.withConstraint {
              reason = "Bundled modules use their PHP release's source and installed SDK.";
            } tvp.packages.${tvp.lib.versions.attrName "php" version};
          };
          opts = (definition.opts or { }) // {
            phpCompatibility.exact = version;
          };
        };
        releases.${version} = release.sha256;
      }
    ) releases
  );
}
