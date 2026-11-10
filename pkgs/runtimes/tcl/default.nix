{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "9.0.0" = {
      builder = ./build-8.6.0.nix;
      base = tvp.bases.default;
      deps = {
        zlib = tvp.packages.zlib_1;
      };
      opts = {
        zipfsImage = false;
      };
    };

    "8.6.2" = {
      builder = ./build-8.6.0.nix;
      base = tvp.bases.default;
      # These configure probes misdetect ANSI headers/strtod under C23.
      opts.cStandard = "gnu89";
      deps = {
        zlib = tvp.packages.zlib_1;
      };
      opts.linkUnwinder = true;
    };

    "8.6.5" = {
      builder = ./build-8.6.0.nix;
      base = tvp.bases.default;
      # These configure probes misdetect ANSI headers/strtod under C23.
      opts.cStandard = "gnu89";
      deps = {
        zlib = tvp.packages.zlib_1;
      };
    };

    "8.6.9" = {
      builder = ./build-8.6.0.nix;
      base = tvp.bases.default;
      deps.zlib = tvp.packages.zlib_1;
    };

    "8.0.2" = {
      builder = ./build-8.0.2.nix;
      # Old configure and strtod declarations require the original C dialect.
      # Measured 8.0/8.1/8.2/8.3/8.4/8.5 failure controls remain enabled.
      opts.cStandard = "gnu89";
      base = tvp.bases.default;
      deps = { };
      opts = {
        reportedVersion = "8.0p2";
      };
      patches = [
        {
          file = ./patches/8.0.3-eopnotsupp-duplicate-case.patch;
          reason = "tclPosixStr.c gives ENOTSUP and EOPNOTSUPP separate case labels, and glibc later made them the same value, so the switch no longer compiles. This is upstream's own guard from 8.0.5 applied earlier.";
        }
      ];
    };

    "8.1.0" = {
      builder = ./build-8.0.2.nix;
      # Old configure and strtod declarations require the original C dialect.
      # Measured 8.0/8.1/8.2/8.3/8.4/8.5 failure controls remain enabled.
      opts.cStandard = "gnu89";
      base = tvp.bases.default;
      deps = { };
      patches = [
        {
          file = ./patches/8.1.0-va-list-assignment.patch;
          reason = "Tcl_AppendResultVA assigns one va_list to another, which is an array type on x86_64 and does not compile. This is upstream's own memcpy from 8.1.1 applied one release earlier.";
        }
      ];
    };

    "8.0.3" = {
      builder = ./build-8.0.2.nix;
      # Old configure and strtod declarations require the original C dialect.
      # Measured 8.0/8.1/8.2/8.3/8.4/8.5 failure controls remain enabled.
      opts.cStandard = "gnu89";
      base = tvp.bases.default;
      deps = { };
      patches = [
        {
          file = ./patches/8.0.3-eopnotsupp-duplicate-case.patch;
          reason = "tclPosixStr.c gives ENOTSUP and EOPNOTSUPP separate case labels, and glibc later made them the same value, so the switch no longer compiles. This is upstream's own guard from 8.0.5 applied two releases earlier.";
        }
      ];
    };

    "8.0.5" = {
      builder = ./build-8.0.2.nix;
      # Old configure and strtod declarations require the original C dialect.
      # Measured 8.0/8.1/8.2/8.3/8.4/8.5 failure controls remain enabled.
      opts.cStandard = "gnu89";
      base = tvp.bases.default;
      deps = { };
    };

    "8.6.0" = {
      builder = ./build-8.6.0.nix;
      base = tvp.bases.default;
      # These configure probes misdetect ANSI headers/strtod under C23.
      opts.cStandard = "gnu89";
      deps = {
        zlib = tvp.packages.zlib_1;
      };
      opts = {
        pkgConfigVersion = "8.6";
        linkUnwinder = true;
      };
    };
  };

  versionTable = tvpLib.packages.mkTable (
    import ./9.nix { inherit defs; } ++ import ./8.nix { inherit defs; }
  );

  pname = "tcl";

  packageArgs = {
    testDeps.pkg-config = tvp.packages.pkg-config;
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        tcl:
        import ./tests {
          inherit pkgs tvpLib tcl;
          pkg-config = tcl.tvp.declaredTestDependencies.pkg-config;
        }
      ) { inherit pkgs; };
    };

    packageMeta = {
      upstream = {
        type = "git-tags";
        url = "https://github.com/tcltk/tcl";

        # Releases are core-8-6-15; everything else in the namespace is a
        # development or merge tag.
        normalise =
          tag:
          if builtins.match "core-[0-9]+-[0-9]+-[0-9]+" tag != null then
            builtins.replaceStrings [ "-" ] [ "." ] (pkgs.lib.removePrefix "core-" tag)
          else
            null;

        include = version: builtins.match "[0-9].*" version != null;
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
    "8.6.18" = {
      constructor = tvp.builder;
      builder = ./native/build-8.6.18.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://prdownloads.sourceforge.net/tcl/tcl${version}-src.tar.gz";
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
        zlib = tvp.packages.zlib_1;
        libgcc = candidate.toolchain.runtime;
      };
    };
    "9.1.0" = {
      constructor = tvp.builder;
      builder = ./native/build-9.1.0.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://prdownloads.sourceforge.net/tcl/tcl${version}-src.tar.gz";
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
      patches = [
        {
          file = ./patches/9.1.0-offline-http-proxy.patch;
          reason = "Tcl 9.1 httpProxy no-proxy tests contact Google without a network constraint. Use the unchanged upstream loopback httpd fixture and retain every response/header/thread assertion in the sandbox. Bind the independent home-directory shell oracle to the declared Bash rather than an absent ambient sh.";
        }
      ];
      deps = {
        patch = constructionTool "patch";
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
        zlib = tvp.packages.zlib_1;
        libgcc = candidate.toolchain.runtime;
      };
    };
  };
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "9.1.0" = versionTable."9.1.0" // {
        def = if native then ownedDefs."9.1.0" else versionTable."9.1.0".def;
      };
      "8.6.18" = versionTable."8.6.18" // {
        def = if native then ownedDefs."8.6.18" else versionTable."8.6.18".def;
      };
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import (if package.version == "9.1.0" then ./tests/native-9.1.nix else ./tests/native-default.nix) {
          inherit pkgs tvpLib package;
        }
      else
        (constructionRecipe.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
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
