{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.0.6" = {
      builder = ./build-1.0.6.nix;
      base = tvp.bases.default;
      deps = { };
    };
    "1.0.8" = {
      builder = ./build-1.0.8.nix;
      base = tvp.bases.default;
      deps = {

      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.0.6";
      releases = {
        "1.0.6" = "sha256-ooSPNPzV1s9H3vAEYfy1KKBITY7e+CCNbS4pCdxh2c0=";
        "1.0.7" = "sha256-52iofFsaeVEUmb60FQC8xMryA3Jv/0am9fmtJ/4Iqys=";
      };
    }
    {
      def = defs."1.0.8";
      releases."1.0.8" = "sha256-q1oDF27hBtPw+pDjgdpHjdrkBZGBU8yiSOaCzQxKImk=";
    }
  ];
  pname = "bzip2";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://sourceware.org/pub/bzip2/";
      pattern = "bzip2-[0-9]+(\\.[0-9]+)+\\.tar\\.(gz|bz2|xz|lz)";
      normalise =
        file:
        let
          match = builtins.match "bzip2-([0-9]+(\\.[0-9]+)+)\\.tar\\.(gz|bz2|xz|lz)" file;
        in
        if match == null then null else builtins.head match;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)+" version != null;
    };
  };
  completed = tvp.bases.default;
  seed =
    reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    };
  ownedDefs = tvpLib.packages.mkDefs {
    "1.0.8" = {
      constructor = tvp.builder;
      builder = ./owned/build-1.0.8.nix;
      base = completed;
      helpers = {
        inherit tvp;
      };
      deps = {
        bash = tvp.packages.bash_5;
        coreutils = seed "Completed Coreutils for build/output operations: canonical Coreutils depends on GMP and would recurse through archive and finalization prerequisites." completed.components.floor.coreutils;
        gnumake = tvp.packages.gnumake_4;
        gnutar = seed "Completed Tar for source extraction: canonical Tar depends on ACL, which shares this prerequisite library wave." completed.components.floor.gnutar;
        gzip = seed "Completed gzip for extraction and manual compression, before rebuilding archive-tool reverse dependencies." completed.components.floor.gzip;
        python = seed "Completed libc construction Python is build-only for explicit source and output operations." completed.components.libc.tvp.deps.python3Minimal;
        binutils = seed "Completed Binutils is build-only for ELF/archive inspection and stripping, without following the canonical compiler graph." completed.components.binutils;
        patchelf = seed "Completed Patchelf is build-only for ELF finalization; canonical Patchelf can require this wave's archive libraries." completed.fixupTools.patchelf;
      };
    };
  };
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "1.0.8" = versionTable."1.0.8" // {
        def = ownedDefs."1.0.8";
      };
    };
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://sourceware.org/pub/bzip2/bzip2-${version}.tar.gz";
        inherit sha256;
      };
    extraArgs.mkTests =
      package:
      packageArgs.extraArgs.mkTests package
      // pkgs.lib.optionalAttrs (package.version == "1.0.8") (
        import ./tests/owned.nix {
          inherit tvp tvpLib package;
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base.stdenv = package.stdenv;
          };

        }
      );
  };
  # Frozen construction selects the complete retained call and test factory.
  constructionRecipe = packageArgs;
  canonical = tvpLib.packages.mkVersions publicArgs;

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
