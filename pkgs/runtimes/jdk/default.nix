{ pkgs, tvp }:
let
  retained = (import ./legacy.nix { inherit pkgs tvp; }).packageArgs;
  pname = "jdk";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-21.0.13.nix;
        base = tvp.baseTiers.full.override { standardTools.pkg-config = tvp.packages.pkg-config; };
        deps = {
          xorgproto = tvp.packages.xorgproto;
          libx11 = tvp.packages.libx11_1;
          libxext = tvp.packages.libxext_1;
          libxrender = tvp.packages.libxrender;
          libxtst = tvp.packages.libxtst_1;
          libxrandr = tvp.packages.libxrandr_1;
          libxt = tvp.packages.libxt_1;
          bootJdk = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "TEMURIN BINARY SEED: exact construction input for OpenJDK 21.0.13; source bootstrap remains blocked.package=jdk-bootstrap-from-source.";
          } tvp.packages.jdk-bootstrap_21_0_13;
          which = tvp.packages.which;
          autoconf = tvp.packages.autoconf_2;
          zip = tvp.packages.zip;
          unzip = tvp.packages.unzip;
          file = tvp.packages.file;
          zlib = tvp.packages.zlib_1;
          alsa = tvp.packages.alsa-lib_1;
          freetype = tvp.packages.freetype_2;
          fontconfig = tvp.packages.fontconfig_2;
          libcups = tvp.packages.libcups_2;
        };
        opts = {
          buildNumber = "9";
          dynamicLinker = "lib/ld-linux-x86-64.so.2";
        };
        patches = [
          {
            file = ./patches/store-paths.patch;
            reason = "Use the declared store shell for executable-script fallback, including libc execvp fast paths which otherwise force /bin/sh; select the owned Fontconfig library for runtime font discovery.";
          }
        ];
      };
      releases."21.0.13" = "sha256-oQ63VvElQrUw25DhWv9ExyzVcroCxHSWr/teNRCBSTU=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta = retained.packageMeta or { };
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://github.com/openjdk/jdk21u/archive/refs/tags/jdk-${version}-ga.tar.gz";
        inherit sha256;
      };
    tests = (import ./tests/provider-context.nix { inherit pkgs; });
  };
  # Preserve only the historical named test-factory override, lazily.
  recipe = family // {
    extraArgs = family.extraArgs // {
      mkTests = import ./tests/caller-factory.nix { inherit pkgs tvp; };
    };
  };
  canonical = tvp.lib.packages.mkVersions recipe;
in
{
  recipes.jdk = recipe // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
