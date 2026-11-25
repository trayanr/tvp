{ tvp, ... }:
let
  pname = "libwebp";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          jpeg = tvp.packages.libjpeg-turbo;
          png = tvp.packages.libpng_1;
        };
      };
      releases."1.6.0" = "sha256-5KtwCb8GKf0RmC1MKqg5ZM8kTP+6c0fs05AZqeOMRWQ=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://chromium.googlesource.com/webm/libwebp";
        prefix = "v";
        include = version: builtins.match "[0-9]+([.][0-9]+)+" version != null;
      };
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
