# A bundled module uses the source and headers of its matching PHP release.
{
  pkgs,
  tvp,
  name,
  opts,
  tests,
  testDeps ? { },
  meta ? { },
  phpRequirements ? { },
  builder ? ./build-bundled.nix,
  deps ? { },
}:
let
  pname = "php-${name}";
  phpFamily = (import ../. { inherit pkgs tvp; }).recipes.php;
  releases = pkgs.lib.filterAttrs (
    version: _: pkgs.lib.versionAtLeast version "8.2"
  ) phpFamily.versionTable;
  versionTable = tvp.lib.packages.mkTable (
    pkgs.lib.mapAttrsToList (version: release: {
      def = {
        inherit builder;
        deps = deps // {
          php = tvp.lib.packages.withConstraint {
            reason = "The bundled ${name} module uses its PHP release's source and installed SDK.";
          } tvp.packages.${tvp.lib.versions.attrName "php" version};
        };
        opts = opts // {
          phpCompatibility.exact = version;
        };
      };
      releases.${version} = release.sha256;
    }) releases
  );
  family = tvp.lib.php.mkExtensionFamily {
    inherit
      tvp
      name
      versionTable
      tests
      testDeps
      ;
    source = phpFamily.source;
    phpPolicy = {
      kind = "bundled";
      requirements = phpRequirements;
    };
    meta = {
      license = pkgs.lib.licenses.php301;
    }
    // meta;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical versionTable;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
