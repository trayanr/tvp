{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "26.13.0" = {
      builder = ./build-26.13.0.nix;
      base = tvp.bases.default;
      deps = {
        bash = tvp.packages.bash_5;
        python = tvp.packages.python_3;
        ninja = tvp.packages.ninja;
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
        patchelf = tvp.packages.patchelf;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
      };
      patches = [
        {
          file = ./patches/store-shell.patch;
          reason = "Resolve the default Unix child-process shell from the declared store input instead of /bin/sh.";
        }
      ];
    };
  };
  pname = "nodejs";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."26.13.0";
      releases."26.13.0" = "sha256-Jj9jns+noXtJQ412zb+a/3MXnjx8t4naabkAcYQn+i4=";
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
  recipes.nodejs = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
