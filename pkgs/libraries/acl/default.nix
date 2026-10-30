{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.3.0" = {
      builder = ./build-2.3.0.nix;
      base = tvp.bases.default;
      deps.attr = tvp.packages.attr_2_5_2;
    };
    "2.3.2" = {
      builder = ./build-2.3.2.nix;
      base = tvp.bases.default;
      deps = {
        attr = tvp.packages.attr_2_5_2;
      };
    };
    "2.4.0" = {
      builder = ./build-2.4.0.nix;
      base = tvp.bases.default;
      deps.attr = tvp.packages.attr_2_5_2;
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.3.0";
      releases = {
        "2.3.0" = "sha256-vTj9u7A8eTdK9RRn6+VJfLwDNbgld/MMlRpBqVtTMAk=";
        "2.3.1" = "sha256-dgxhxokBs3/dXu/ur0wMeia9/disdHoe3/HODiQ8Ea8=";
      };
    }
    {
      def = defs."2.3.2";
      releases."2.3.2" = "sha256-XyvbrWKXB6p9hcYj+ZSqih0t7FWnPeUgW6wL9gWKL3w=";
    }
    {
      def = defs."2.4.0";
      releases."2.4.0" = "sha256-c8hTw9ROH2k+WpaphvG9GdPQ2sLH1FPnlhd3dLxOX2o=";
    }
  ];
  pname = "acl";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://download.savannah.nongnu.org/releases/acl/";
      # Extract complete archive filenames before applying the strict family parser.
      pattern = "[^\"<>[:space:]]+\\.tar\\.(gz|xz)[^\"<>[:space:]]*";
      normalise =
        filename:
        let
          m = builtins.match "acl-([0-9]+\\.[0-9]+\\.[0-9]+)(\\.src)?\\.tar\\.(gz|xz)" filename;
        in
        if m == null then null else builtins.head m;
    };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
