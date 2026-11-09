{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.4.20" = {
      builder = ./build-2.4.20.nix;
      base = tvp.bases.default;
      deps = {
        dnssd =
          tvpLib.packages.withConstraint
            {
              category = "construction";
              reason = "Retained libdns_sd counterpart preserves the complete pre-migration libcups profile and public variant identities.";
            }
            (
              (tvpLib.packages.mkVersions
                (import ../libdns_sd { inherit pkgs tvp; }).recipes.libdns_sd.constructionRecipe
              ).libdns_sd_2881_120_11
            );
        pkg-config = tvp.packages.pkg-config;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
        patchelf = tvp.packages.patchelf;
      };
    };
  };
  pname = "libcups";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.4.20";
      releases."2.4.20" = "sha256-q02c1/PlgGAJHSsklyIj1kAWdfEcSbZav09u8x3qIv8=";
    }
  ];
  packageArgs = {
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
  # Ordinary native release only. Frozen construction retains the complete call.
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is an explicit build host tool, independent of this ordinary library target.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "2.4.20" = {
      constructor = tvp.builder;
      builder = ./native/build-2.4.20.nix;
      base = candidate.base;
      patches = [
        {
          file = ./patches/testfile-explicit-search-path.patch;
          reason = "Upstream file tests assume /bin/cat. Keep single-directory and path-list searches against explicitly declared sandbox Coreutils.";
        }
      ];
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://github.com/OpenPrinting/cups/releases/download/v${version}/cups-${version}-source.tar.gz";
          inherit sha256;
        };
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        patch = constructionTool "patch";
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        findutils = constructionTool "findutils";
        gzip = constructionTool "gzip";
        pkgConfig = tvp.packages.pkg-config;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
        dnssd = tvp.packages.libdns_sd;
      };
    };
  };
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "2.4.20" = versionTable."2.4.20" // {
        def = if native then ownedDefs."2.4.20" else versionTable."2.4.20".def;
      };
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix { inherit package; }
      else
        (
          package:
          import ./tests {
            inherit tvpLib package;
            pkgs = tvpLib.tests.withBase {
              inherit pkgs;
              base.stdenv = package.stdenv;
            };

          }
        )
          package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
