{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.56.0" = {
      builder = ./build-2.56.0.nix;
      base = tvp.bases.default;
      deps = {
        rustc = (
          tvpLib.packages.withConstraint {
            category = "construction";
            reason = "Retained complete Rust seed generation; historical construction and tests must not follow the promoted public provider.";
          } (import ../../compilers/rust/legacy.nix { inherit pkgs tvp; }).canonical.rustc_1_97_1
        );
        cargo = (
          tvpLib.packages.withConstraint
            {
              category = "construction";
              reason = "Retained complete Cargo seed generation for historical construction.";
            }
            (import ../../build-tools/cargo-bootstrap/legacy.nix { inherit pkgs tvp; })
            .canonical.cargo-bootstrap_1_97_1
        );
        pkg-config = tvp.packages.pkg-config;
        patchelf = tvp.packages.patchelf;
        bash = tvp.packages.bash_5;
        perl = tvp.packages.perl_5;
        python = tvp.packages.python_3;
        curl = tvp.packages.curl_8;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
        expat = tvp.packages.expat_2;
        pcre2 = tvp.packages.pcre2_10;
      };
    };
  };
  pname = "git";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.56.0";
      releases."2.56.0" = "sha256-JsVsKWs4wGlbJvqV9HXx0BcE0tOOc0ZcowsLL13HidM=";
    }
  ];
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
in
{
  recipes.git = packageArgs // {
    constructionRecipe = packageArgs;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
