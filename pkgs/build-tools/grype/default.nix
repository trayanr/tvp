{ pkgs, tvp }:
let
  pname = "grype";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          go = tvp.packages.go;
          certificates = tvp.packages.ca-certificates;
          runtimeShell = tvp.packages.bash;
        };
        opts = {
          vendorHash = "sha256-ZvRXdBLykeyMXHyCI0pqZQ2FOVbsgasFx4rDsBZYbmY=";
          revision = "8f3ddeddc4a4ed6314248aaf0a7c510f98db8882";
        };
      };
      releases."0.122.1" = "sha256-2AHQhNJNGc2Rajy0qqHhKyaDP1BpjNloyf+BWg54ObQ=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://github.com/anchore/grype/archive/refs/tags/v${version}.tar.gz";
      fetch =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          name = "grype-${version}.tar.gz";
          url = "https://github.com/anchore/grype/archive/refs/tags/v${version}.tar.gz";
          inherit sha256;
        };
      discovery = {
        type = "git-tags";
        url = "https://github.com/anchore/grype.git";
        normalise = tag: pkgs.lib.removePrefix "v" tag;
        include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
      };
    };
    tests = import ./tests.nix;
    testDeps.python = tvp.packages.python_3;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.grype = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
