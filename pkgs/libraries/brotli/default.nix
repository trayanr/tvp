{ tvp, ... }:
let
  pname = "brotli";
  versionTable = tvp.lib.packages.mkTable [
    {
      def.builder = ./build.nix;
      releases."1.2.1" = "sha256-mNNdEaeNxFOuu30Qw3SPP3P/eMgmfA3Gl7hjH2e/fo8=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://codeload.github.com/google/brotli/tar.gz/refs/tags/v${version}";
      discovery = {
        type = "git-tags";
        url = "https://github.com/google/brotli.git";
        prefix = "v";
        include = version: builtins.match "[0-9]+[.][0-9]+[.][0-9]+" version != null;
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
