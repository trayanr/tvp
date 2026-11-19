{ tvp, ... }:
let
  pname = "shellcheck";
  project = "https://github.com/koalaman/shellcheck";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        blob = {
          reason = "Use the official static ShellCheck release to validate TVP's shell wrappers without a Nixpkgs Haskell package.";
          needs = "A TVP GHC bootstrap, Cabal and pinned source dependencies for a source-built ShellCheck.";
          blocked.package = "shellcheck-from-source";
        };
      };
      releases."0.10.0" = "sha256-bIgasGmOTm6iNSRfIoMoYFRPF7o4ZEL+fp1in4y+34c=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version: "${project}/releases/download/v${version}/shellcheck-v${version}.linux.x86_64.tar.xz";
      discovery = {
        type = "git-tags";
        url = project;
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
