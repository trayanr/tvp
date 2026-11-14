{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-0.27.nix;
        # The bundled GLib 2.32.3 configure requires msgfmt.
        deps.gettext = tvp.packages.gettext;
        patches = [
          {
            file = ./patches/charset-directory.patch;
            reason = "Use the final base libc charset directory instead of a build prefix; preserve CHARSETALIASDIR and missing-file fallback.";
          }
        ];
      };
      releases."0.27" = "sha256-eaa0PuZjPJ5swD6xcGNwu3qEUGWYRbeCQR+WnqumVqQ=";
    }
    {
      def = {
        builder = ./build-0.27.1.nix;
        patches = [
          {
            file = ./patches/charset-directory.patch;
            reason = "Use the final base libc charset directory instead of a build prefix; preserve CHARSETALIASDIR and missing-file fallback.";
          }
        ];
      };
      releases = {
        "0.27.1" = "sha256-T2PQ3zA1EBsSlJJQ2lIxr0njw6/Nj7GFVPp8PLktjBc=";
        "0.28" = "sha256-a26zHG7EQhF0V4ZSx+FB/ari2rrRAh9CDYcTIGrB+EU=";
        "0.29" = "sha256-yFB3BdKhDGfzhdZsoqrjHoF3DMBzS0GR64xInoZKAGs=";
        "0.29.1" = "sha256-vrQ8ngZFVUab1DkNz9gDCxU24KoQPwjXq/eujKwMsAE=";
      };
    }
    {
      def = {
        builder = ./build-0.29.2.nix;
        patches = [
          {
            file = ./patches/charset-directory.patch;
            reason = "Use the final base libc charset directory instead of a build prefix; preserve CHARSETALIASDIR and missing-file fallback.";
          }
        ];
      };
      releases."0.29.2" = "sha256-b8acAWiMlFilfrmhZkyaujcszaQgoCv0Qp/mEOfn1ZE=";
    }
  ];
  packageMeta = {
    upstream = {
      type = "directory-index";
      url = "https://pkg-config.freedesktop.org/releases/";
      pattern = "pkg-config-[0-9][^\"]*\\.tar\\.gz";

      normalise =
        file:
        if pkgs.lib.hasPrefix "pkg-config-" file && pkgs.lib.hasSuffix ".tar.gz" file then
          pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "pkg-config-" file)
        else
          null;

      include = version: builtins.match "[0-9].*" version != null;
    };
  };
  pname = "pkg-config";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://pkg-config.freedesktop.org/releases/pkg-config-${version}.tar.gz";
        inherit sha256;
      };
    testDeps = {
      mpfr = tvp.packages.mpfr;
      pkgConfig = tvp.packages.pkg-config;
      runtimeShell = tvp.packages.bash_5;
      alternateCoreutils = tvp.packages.coreutils;
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.pkg-config = family // {
    constructionRecipe = import ./retained { inherit pkgs tvp; };
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
