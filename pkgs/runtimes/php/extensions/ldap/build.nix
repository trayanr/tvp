# Select the library inputs for the bundled ldap procedure.
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
  openldap,
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
  procedure =
    import ../build-bundled.nix
      (builtins.removeAttrs args [ "openldap" ] // { inherit configureOptions loader; })
      (
        final
        // {
          configureOptions = [ "--with-ldap=${final.openldap}" ] ++ final.configureOptions;
          linkLibraries = final.openldap.specification.runtime.libraries ++ final.linkLibraries;
          libraries = [ final.openldap ] ++ final.libraries;
        }
      );
in
procedure // { inherit openldap; }
