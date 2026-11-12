{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "1.19" = {
      builder = ./build-1.9.nix;
      base = tvp.bases.default;
      deps = { };
      # src/var.c uses bool as a field name; upstream 1.25 renamed it.
      opts.cStandard = "gnu17";
    };

    "1.25" = {
      builder = ./build-1.9.nix;
      base = tvp.bases.default;
      deps = { };
    };

    # libgdbmapp uses common symbols; its old C declarations also predate C23.
    "1.11" = {
      builder = ./build-1.9.nix;
      base = tvp.bases.default;
      deps = { };
      opts = {
        cStandard = "gnu89";
        commonSymbols = true;
      };
    };

    "1.10" = {
      builder = ./build-1.9.nix;
      base = tvp.bases.default;
      deps = { };
    };

    "1.9" = {
      builder = ./build-1.9.nix;
      base = tvp.bases.default;
      deps = { };
      opts = {
        touchTestsuite = true;
      };
    };

    "1.8.0" = {
      builder = ./build-1.7.3.nix;
      base = tvp.bases.default;
      deps = { };
      opts.cStandard = "gnu89";
      patches = [
        {
          file = ./patches/1.8.0-config-sub-x86_64.patch;
          reason = "The shipped config.sub predates x86_64; accept its native CPU spelling without changing libtool's Linux rules.";
        }
      ];
    };

    "1.8.1" = {
      builder = ./build-1.7.3.nix;
      base = tvp.bases.default;
      deps = { };
      opts.cStandard = "gnu89";
    };

    "1.7.3" = {
      builder = ./build-1.7.3.nix;
      base = tvp.bases.default;
      deps = { };
      opts.cStandard = "gnu89";
      patches = [
        {
          file = ./patches/1.7.3-install-compat-unbalanced-paren.patch;
          reason = "install-compat writes 100 1 26 57 100 131 989 991srcdir/ndbm.h — an unbalanced paren make expands to nothing, so the target installs no ndbm.h at all.";
        }
      ];
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./1.nix { inherit defs; });

  pname = "gdbm";

  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests =
        gdbm:
        import ./tests {
          inherit pkgs tvpLib gdbm;
        };
    };

    packageMeta = {
      upstream = {
        type = "directory-index";
        url = "https://mirrors.kernel.org/gnu/gdbm/";
        pattern = "gdbm-[0-9][^\"]*\\.tar\\.gz";

        normalise =
          file:
          if pkgs.lib.hasPrefix "gdbm-" file && pkgs.lib.hasSuffix ".tar.gz" file then
            pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "gdbm-" file)
          else
            null;

        include =
          version:
          builtins.match "[0-9].*" version != null
          && !(pkgs.lib.hasInfix "alpha" version || pkgs.lib.hasInfix "beta" version);
      };
    };
  };

  # Preserve the complete pre-promotion factory/table and its historical callers.
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is the explicit host generation, independent of the ordinary target being built.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "1.26" = {
      constructor = tvp.builder;
      builder = ./native/build-1.26.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/gdbm/gdbm-${version}.tar.gz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      helpers = {
        inherit tvp;
      };
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        pkgConfig = constructionTool "pkgConfig";
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
      };
    };
  };
  ordinaryDefs = import ./ordinary {
    inherit
      tvp
      tvpLib
      candidate
      constructionTool
      ;
    fetchurl = pkgs.fetchurl;
  };
  ordinaryRoutes = {
    "1.8.0" = "1.8.0";
    "1.8.2" = "1.8.2";
    "1.8.3" = "1.8.2";
    "1.9" = "1.9";
    "1.9.1" = "1.9";
    "1.10" = "1.10";
    "1.11" = "1.11";
    "1.12" = "1.11";
    "1.13" = "1.11";
    "1.14" = "1.11";
    "1.14.1" = "1.11";
    "1.15" = "1.11";
    "1.16" = "1.11";
    "1.17" = "1.11";
    "1.18" = "1.11";
    "1.18.1" = "1.11";
    "1.19" = "1.19";
    "1.20" = "1.19";
    "1.21" = "1.19";
    "1.22" = "1.19";
    "1.23" = "1.19";
    "1.24" = "1.19";
    "1.25" = "1.25";
  };
  previousPublicArgs = packageArgs // {
    versionTable =
      versionTable
      // (builtins.mapAttrs (
        version: start:
        versionTable.${version}
        // {
          def = if native then ordinaryDefs.${start} else versionTable.${version}.def;
        }
      ) ordinaryRoutes)
      // {
        "1.26" = versionTable."1.26" // {
          def = if native then ownedDefs."1.26" else versionTable."1.26".def;
        };
      };
    extraArgs.mkTests =
      package:
      if package ? testContext && builtins.hasAttr package.version ordinaryRoutes then
        import ./tests/ordinary.nix {
          inherit
            pkgs
            tvp
            tvpLib
            package
            ;
        }
      else if package ? testContext then
        import ./tests/native-default.nix { inherit pkgs tvpLib package; }
      else
        constructionRecipe.extraArgs.mkTests package;
  };
  compatibilityDefs = import ./compatibility { inherit tvp tvpLib candidate defs; };
  compatibilityVersions = [ "1.7.3" "1.8.1" ];
  publicArgs = previousPublicArgs // {
    versionTable = previousPublicArgs.versionTable // builtins.listToAttrs (map (version: {
      name = version;
      value = versionTable.${version} // { def = if native then compatibilityDefs.${version} else versionTable.${version}.def; };
    }) compatibilityVersions);
    extraArgs = previousPublicArgs.extraArgs // {
      mkTests = package:
        if package ? testContext && builtins.elem package.version compatibilityVersions then
          import ./tests { inherit pkgs tvpLib; gdbm = package; }
          else previousPublicArgs.extraArgs.mkTests package;
    };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    inherit
      pname
      versionTable
      canonical
      ;
  };
}
