{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "4.4.5" = {
      builder = ./build-4.4.5.nix;
      base = tvp.bases.default;
      deps = {
        bash = tvp.packages.bash_5;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        zstd = tvp.packages.zstd_1;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/store-shell.patch;
          reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
        }
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.4.5";
      releases."4.4.5" = "sha256-oMVMiKu4B43Y7MrbcX/GuxlL8Y59RMhjCZECiIhuBOI=";
    }
  ];
  pname = "cmake";
  testDeps = {
    ninja = tvp.packages.ninja;
  };
  packageArgs = {
    inherit testDeps;
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;
        ninja = package.tvp.declaredTestDependencies.ninja;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      }
    ) { inherit pkgs; };
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/Kitware/CMake.git";
      normalise = tag: pkgs.lib.removePrefix "v" tag;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
    };
  };
  # Complete prior family: source, patches, test factory and arguments remain
  # available to frozen construction and historical public test universes.
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} host tool is independent of ordinary frontend consumers.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "4.4.5" = {
      constructor = tvp.builder;
      builder = ./native/build-4.4.5.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://github.com/Kitware/CMake/releases/download/v${version}/cmake-${version}.tar.gz";
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
        coreutils = constructionTool "coreutils";
        gnutar = constructionTool "tar";
        gzip = constructionTool "gzip";
        findutils = constructionTool "findutils";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        helperPython = constructionTool "python";
        patch = constructionTool "patch";
        gnumake = constructionTool "make";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        diffutils = constructionTool "diffutils";
        gawk = constructionTool "gawk";
        bash = tvp.packages.bash_5;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib_1;
        bzip2 = tvp.packages.bzip2_1;
        xz = tvp.packages.xz_5;
        zstd = tvp.packages.zstd_1;
        pkg-config = tvp.packages.pkg-config;
      };
      opts = {
        docDirectory = "share/doc/cmake-4.4";
        # System codec selection must not drop notices in the public payload.
        bundledLicenseFiles = [
          "Utilities/cmliblzma/COPYING"
          "Utilities/cmzlib/Copyright.txt"
          "Utilities/cmzstd/LICENSE"
        ];
      };
      patches = [
        {
          file = ./patches/store-shell.patch;
          reason = "Bind generated Makefile and execute_process shell commands to the selected Bash in store-only sandboxes.";
        }
      ];

    };
  };
  installedArgs = packageArgs // {
    versionTable = versionTable // {
      "4.4.5" = versionTable."4.4.5" // {
        def = if native then ownedDefs."4.4.5" else versionTable."4.4.5".def;
      };
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native-default.nix {
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

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
