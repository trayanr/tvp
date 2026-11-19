{ pkgs, tvp }:
let
  inherit (pkgs.lib) replaceStrings versionOlder;
  pname = "icu";
  project = "https://github.com/unicode-org/icu";
  versionTable = tvp.lib.packages.mkTable [
    {
      def.builder = ./build.nix;
      releases."74.2" = "sha256-aNsIIhKpbW9T411g9H04uWLp+dIHp0z6x4Apro/14Iw=";
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
