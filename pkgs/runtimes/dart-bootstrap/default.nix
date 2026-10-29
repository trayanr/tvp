{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "3.13.0-103.1.beta" = {
      builder = ./build-3.13.0-103.1.beta.nix;
      base = tvp.bases.default;
      deps = {
        unzip = tvp.packages.unzip_6_0;
        patchelf = tvp.packages.patchelf_0_19_2;
      };
      opts = {
        inherit (platform) dynamicLinker;
        channel = "beta";
      };
      blob = {
        reason = "The exact upstream Dart SDK bootstrap version pinned by Dart 3.13.7's DEPS file.";
        needs = "A source Dart bootstrap chain which can generate the kernel and compiler snapshots needed for the source SDK build.";
        blocked.package = "dart-bootstrap-from-source";
      };
    };
    "3.13.7" = {
      builder = ./build-3.13.0-103.1.beta.nix;
      base = tvp.bases.default;
      deps = {
        unzip = tvp.packages.unzip_6_0;
        patchelf = tvp.packages.patchelf_0_19_2;
      };
      opts = {
        inherit (platform) dynamicLinker;
        channel = "stable";
      };
      blob = {
        reason = "Pinned upstream binary SDK; supplies the matching precompiled DevTools web assets while the VM and language tools are built from source separately.";
        needs = "Source-built Flutter/web tooling to rebuild DevTools and a source Dart bootstrap chain.";
        blocked.package = "dart-devtools-from-source";
      };
    };
  };
  pname = "dart-bootstrap";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.13.0-103.1.beta";
      releases."3.13.0-103.1.beta" = "sha256-sJpFXJillGn1igtM9yISkOf3mEOgd4MVRfAzLC9Dlu4=";
    }
    {
      def = defs."3.13.7";
      releases."3.13.7" = "sha256-65mu0mbvvLYVxq4hwS9Sz+k1ufIIvMxf6n9kwh6Gcik=";
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
