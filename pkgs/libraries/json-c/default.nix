{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "0.19" = {
      constructor = tvp.builder;
      builder = ./build-0.19.nix;
      helpers = {
        inherit tvp;
      };
      base = tvp.bases.default;
      deps = {
        inherit (tvp.packages)
          cmake
          bash
          coreutils
          gnumake
          gnutar
          gzip
          patch
          ;
        python = tvp.packages.python-build_3;
        binutils = tvp.bases.default.stdenv.cc.bintools.bintools;
        patchelf = tvp.packages.patchelf_0;
      };
      patches = [
        {
          file = ./patches/posix-test-byte.patch;
          reason = "Emit the same incomplete UTF-8 byte with POSIX printf instead of undeclared xxd in the upstream CLI fixture.";
        }
      ];
    };
  };
  pname = "json-c";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."0.19";
      releases."0.19" = "sha256-N60CSZAuMBvZBSv3EuUR/Mas/07KrUtZAKrZzlZOJt4=";
    }
  ];
  source =
    { version, sha256 }:
    pkgs.fetchurl {
      url = "https://github.com/json-c/json-c/releases/download/json-c-${version}-20260627/json-c-${version}.tar.gz";
      inherit sha256;
    };
  packageArgs = {
    inherit pname versionTable source;
    testDeps = {
      inherit (tvp.packages) pkg-config cmake;
    };
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      let
        testPkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      in
      import ./tests {
        inherit tvpLib package;
        pkgs = testPkgs;
        pkg-config = package.tvp.declaredTestDependencies.pkg-config;
      }
      // import ./tests/build-steps.nix {
        inherit tvpLib package;
        pkgs = testPkgs;
      }
    ) { inherit pkgs; };
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/json-c/json-c.git";
      normalise =
        tag:
        let
          m = builtins.match "json-c-([0-9]+[.][0-9]+([.][0-9]+)?)-[0-9]{8}" tag;
        in
        if m == null then null else builtins.head m;
    };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles.build-steps = {
        base = tvp.bases.default;
        versions = pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
          "0.19" = { };
        };
      };
    }
  );
  aliases = tvpLib.packages.mkAliases {
    inherit pname versionTable canonical;
    lines = [ "0" ];
  };
}
