{ pkgs, tvp }:
let
  lib = tvp.lib;
  candidate = import ../../../bases/source-gnu { };
  host =
    name:
    lib.packages.withConstraint {
      category = "construction";
      reason = "Source-owned build tool independent of the pager's ordinary reverse consumers.";
    } candidate.tools.${name};
  defs = lib.packages.mkDefs {
    "710" = {
      constructor = tvp.builder;
      builder = ./build-710.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
        lib = pkgs.lib;
      };
      testContext =
        package:
        lib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      patches = [
        {
          file = ./patches/bulk-preprocessor-errors.patch;
          reason = "With explicit --show-preproc-error and captured output, report preprocessor failures on stderr and return nonzero; keep interactive/default fallback behavior.";
        }
      ];
      deps = {
        # Bash is an installed runtime provider, not merely a construction tool.
        bash = candidate.tools.bash;
        coreutils = host "coreutils";
        gnumake = host "make";
        gnutar = host "tar";
        gzip = host "gzip";
        findutils = host "findutils";
        sed = host "sed";
        grep = host "grep";
        gawk = host "gawk";
        python = host "python";
        binutils = host "linker";
        patchelf = host "patchelf";
        patch = host "patch";
        ncurses = tvp.packages.ncurses_6;
        pcre2 = tvp.packages.pcre2_10;
      };
    };
  };
  versionTable = lib.packages.mkTable [
    {
      def = defs."710";
      releases."710" = "sha256-0QCPt43K4TI92rZkvLNSph8CKxsTG9gBhUjgIdl17Ho=";
    }
  ];
  pname = "less";
  recipe = {
    inherit pname versionTable;
    infra = {
      inherit (pkgs) lib;
    };
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://www.greenwoodsoftware.com/less/less-${version}.tar.gz";
        inherit sha256;
      };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://www.greenwoodsoftware.com/less/download.html";
      pattern = "less-[0-9]+\\.tar\\.gz";
      normalise =
        file:
        let
          m = builtins.match "less-([0-9]+)\\.tar\\.gz" file;
        in
        if m == null then null else builtins.head m;
      include = version: builtins.match "[0-9]+" version != null;
    };
    testDeps = {
      diffutils = host "diffutils";
      perl = host "perl";
    };
    extraArgs.mkTests = package: import ./tests { inherit package tvp; };
  };
  canonical = lib.packages.mkVersions recipe;
in
{
  recipes.less = recipe;
  inherit canonical;
  aliases = lib.packages.mkAliases { inherit pname versionTable canonical; };
}
