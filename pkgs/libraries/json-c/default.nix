{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "0.19" = {
      builder = ./build-0.19.nix;
      base = tvp.bases.default;
      deps.cmake = tvp.packages.cmake;
      opts.tagDate = "20260627";
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
  packageArgs = {
    inherit pname versionTable;
    testDeps.pkg-config = tvp.packages.pkg-config;
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
        pkg-config = package.tvp.declaredTestDependencies.pkg-config;
      };
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
  aliases = tvpLib.packages.mkAliases {
    inherit pname versionTable canonical;
    lines = [ "0" ];
  };
}
