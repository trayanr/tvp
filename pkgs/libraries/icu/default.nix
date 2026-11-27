{ pkgs, tvp }:
let
  inherit (pkgs.lib) replaceStrings versionOlder;
  pname = "icu";
  project = "https://github.com/unicode-org/icu";
  versionTable = tvp.lib.packages.mkTable [
    {
      def.builder = ./build.nix;
      releases = {
        "74.2" = "sha256-aNsIIhKpbW9T411g9H04uWLp+dIHp0z6x4Apro/14Iw=";
        "75.1" = "sha256-y5aN8+TS6H6LEcSaXQHHh70TuVRSgPxmQvgmUnYYyu8=";
        "76.1" = "sha256-36y0a/5HR0EEcs4+EUS/KKEC/uqk44dbrJtMbPMPTz4=";
        "77.1" = "sha256-WI5DH3cyfDkDH/u4hDwOO8EiwhE3RIX6h9xfP6/yQGE=";
        "78.1" = "sha256-Yhf1jKObIxJ2Bc/Gx+DTR1/ksNYxVwETg9cWy0FheIY=";
        "78.2" = "sha256-Pploe1xDXUsgljDi0uu3mQbJhGheeGNQeLZy4DyJ3zU=";
        "78.3" = "sha256-Oi56R2BLpwLzRYeDCOb+/sphLuiVz0pfIi55Vfq/4MA=";
        "79.1" = "sha256-Bvpj7LUhBI+AgvEq2Yj2tnjZDL2IqvziTLyUkCsZHZk=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        # ICU 78 switched to dotted release tags and source asset names.
        if versionOlder version "78" then
          "${project}/releases/download/release-${replaceStrings [ "." ] [ "-" ] version}/icu4c-${
            replaceStrings [ "." ] [ "_" ] version
          }-src.tgz"
        else
          "${project}/releases/download/release-${version}/icu4c-${version}-sources.tgz";
      discovery = {
        type = "git-tags";
        url = project;
        normalise =
          tag:
          let
            matched = builtins.match "release-([0-9]+([.-][0-9]+)+)" tag;
          in
          if matched == null then null else replaceStrings [ "-" ] [ "." ] (builtins.head matched);
      };
    };
    tests = import ./tests.nix;
    testDeps.pkg-config = tvp.packages.pkg-config;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
