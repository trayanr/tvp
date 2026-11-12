{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  constructionRecipe = previous.recipes.file;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  host =
    name: reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "5.48" = {
      constructor = tvp.builder;
      builder = ./native/build-5.48.nix;
      base = candidate.base;
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
        zlib = tvp.packages.zlib_1;
        xz = tvp.packages.xz_5;
        bzip2 = tvp.packages.bzip2_1;
        zstd = tvp.packages.zstd_1;
        bash = tvp.packages.bash_5;
        coreutils = tvp.packages.coreutils_9;
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        gzip = tvp.packages.gzip_1;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
        binutils = host "linker" "Owned ELF output tools selected independently of catalogue consumers.";
        patchelf = host "patchelf" "Owned output RPATH tool independent of catalogue consumers.";
      };
    };
    "5.45" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-5.45.nix;
      base = candidate.base;
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
        zlib = tvp.packages.zlib_1;
        xz = tvp.packages.xz_5;
        bzip2 = tvp.packages.bzip2_1;
        zstd = tvp.packages.zstd_1;
        bash = tvp.packages.bash_5;
        coreutils = tvp.packages.coreutils_9;
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        gzip = tvp.packages.gzip_1;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
        binutils = host "linker" "Owned ELF output tools selected independently of catalogue consumers.";
        patchelf = host "patchelf" "Owned output RPATH tool independent of catalogue consumers.";
      };
    };
  };
  versionTable = constructionRecipe.versionTable // {
    "5.48" = constructionRecipe.versionTable."5.48" // {
      def = if native then defs."5.48" else constructionRecipe.versionTable."5.48".def;
    };
    "5.45" = constructionRecipe.versionTable."5.45" // {
      def = if native then defs."5.45" else constructionRecipe.versionTable."5.45".def;
    };
    "5.46" = constructionRecipe.versionTable."5.46" // {
      def = if native then defs."5.45" else constructionRecipe.versionTable."5.46".def;
    };
    "5.47" = constructionRecipe.versionTable."5.47" // {
      def = if native then defs."5.45" else constructionRecipe.versionTable."5.47".def;
    };
  };

  installedArgs = constructionRecipe // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        urls = [
          "https://astron.com/pub/file/file-${version}.tar.gz"
        ];
        inherit sha256;
      };
    testDeps = {
      python = candidate.tools.python;
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
      alternateZlib = (import ../../../bootstrap/source-full-gcc-prerequisites.nix { }).zlib;
      pkgconfig = tvp.packages.pkg-config;
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import
          (
            if
              builtins.elem package.version [
                "5.45"
                "5.46"
                "5.47"
              ]
            then
              ./tests/ordinary.nix
            else
              ./tests/native-default.nix
          )
          {
            inherit
              pkgs
              tvp
              tvpLib
              package
              ;
          }
      else
        constructionRecipe.extraArgs.mkTests package
    ) { inherit pkgs; };
  };
  publicArgs = installedArgs // {
    extraArgs = installedArgs.extraArgs // {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        package:
        (
          if installedArgs.extraArgs.mkTests ? override then
            (installedArgs.extraArgs.mkTests.override { inherit pkgs; }) package
          else
            installedArgs.extraArgs.mkTests package
        )
        // (import ../owned-split-tests.nix { inherit pkgs tvp package; })
      ) { inherit pkgs; };
    };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "file";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
