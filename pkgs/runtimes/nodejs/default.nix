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
          tvp.lib.packages.withConstraint {
            category = "artifact";
            reason = "Matched released SDK/toolchain payload or profile test artifact; changing its release changes the declared artifact identity.";
          } tvp.canonical.rustc_1_97_1
        );
        cargo = (
          tvp.lib.packages.withConstraint {
            category = "artifact";
            reason = "Matched released SDK/toolchain payload or profile test artifact; changing its release changes the declared artifact identity.";
          } tvp.canonical."cargo-bootstrap_1_97_1"
        );
        patchelf = tvp.packages.patchelf;
        openssl = tvp.packages.openssl_3;
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
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
