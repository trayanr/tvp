{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        # Measured FORTIFY failures require the exact GCC13 compiler/libc.
        # Adapt its interface with the existing retained tier; do not swap base.
        base = tvp.baseTiers.retained.gcc13-owned-v3;
        deps.attr = tvp.packages.attr_2;
        opts.installedInterface = {
          libraryFile = "libacl.so.1.1.230";
          runtimeAttr = true;
          propagateAttr = true;
        };
        opts.upstreamProfile = "test";
      };
      releases."2.3.0" = "sha256-vTj9u7A8eTdK9RRn6+VJfLwDNbgld/MMlRpBqVtTMAk=";
    }
    {
      def = {
        builder = ./build.nix;
        base = tvp.baseTiers.retained.gcc13-owned-v3;
        deps.attr = tvp.packages.attr_2;
        opts.installedInterface = {
          libraryFile = "libacl.so.1.1.2301";
          runtimeAttr = true;
          propagateAttr = true;
        };
        opts.upstreamProfile = "test";
      };
      releases."2.3.1" = "sha256-dgxhxokBs3/dXu/ur0wMeia9/disdHoe3/HODiQ8Ea8=";
    }
    {
      def = {
        builder = ./build.nix;
        deps.attr = tvp.packages.attr_2;
        opts.installedInterface = {
          libraryFile = "libacl.so.1.1.2302";
          runtimeAttr = true;
          propagateAttr = false;
        };
        opts.upstreamProfile = "test";
      };
      releases."2.3.2" = "sha256-XyvbrWKXB6p9hcYj+ZSqih0t7FWnPeUgW6wL9gWKL3w=";
    }
    {
      def = {
        builder = ./build.nix;
        deps.attr = tvp.packages.attr_2;
        opts.installedInterface = {
          libraryFile = "libacl.so.1.2.2400";
          runtimeAttr = false;
          propagateAttr = false;
        };
      };
      releases."2.4.0" = "sha256-c8hTw9ROH2k+WpaphvG9GdPQ2sLH1FPnlhd3dLxOX2o=";
    }
  ];
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
  pname = "acl";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://download.savannah.nongnu.org/releases/acl/acl-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
    testDeps = {
      pkg-config = tvp.packages.pkg-config;
      perl = tvp.packages.perl_5;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.acl = family // {
    constructionRecipe = import ./retained.nix { inherit pkgs tvp; };
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
