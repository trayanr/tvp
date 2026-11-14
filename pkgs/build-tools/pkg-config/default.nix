{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "0.27" = {
      builder = ./build-0.27.nix;
      base = tvp.bases.default;
      # Bundled GLib uses bool as a field name, reserved by C23. Preserve its
      # original dialect on modern compilers; older construction is unchanged.
      opts.cStandard = "gnu17";
      deps = {
        # Historical 0.27 keeps the prior effective Gettext/JDK seed closure.
        gettext = tvp.packages.gettext.override {
          jdk = (
            tvp.packages.jdk_21.override {
              bootJdk =
                (import ../../runtimes/jdk-bootstrap/legacy.nix { inherit pkgs tvp; })
                .canonical.jdk-bootstrap_21_0_13;
            }
          );
        };
      };
    };

    "0.27.1" = {
      builder = ./build-0.27.1.nix;
      base = tvp.bases.default;
      # Bundled GLib uses bool as a field name, reserved by C23. Preserve its
      # original dialect on modern compilers; older construction is unchanged.
      opts.cStandard = "gnu17";
      deps = { };
    };

    "0.29.2" = {
      builder = ./build-0.29.2.nix;
      base = tvp.bases.default;
      # Bundled GLib uses bool as a field name, reserved by C23. Preserve its
      # original dialect on modern compilers; older construction is unchanged.
      opts.cStandard = "gnu17";
      deps = { };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./0.nix { inherit defs; });

  pname = "pkg-config";

  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests = pkgs.lib.makeOverridable (
        { pkgs }:
        pkgConfig:
        import ./tests {
          inherit tvpLib pkgConfig;
          pkgs = tvpLib.tests.withBase {
            inherit pkgs;
            base.stdenv = pkgConfig.stdenv;
          };
        }
      ) { inherit pkgs; };
    };

    packageMeta = {
      upstream = {
        type = "directory-index";
        url = "https://pkg-config.freedesktop.org/releases/";
        pattern = "pkg-config-[0-9][^\"]*\\.tar\\.gz";

        normalise =
          file:
          if pkgs.lib.hasPrefix "pkg-config-" file && pkgs.lib.hasSuffix ".tar.gz" file then
            pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "pkg-config-" file)
          else
            null;

        include = version: builtins.match "[0-9].*" version != null;
      };
    };
  };

  # Evaluation metadata only: keep the existing producers and installed paths.
  withProvider =
    package:
    let
      decorate =
        value:
        value
        // {
          buildEnvironment = import ../../../lib/pkg-config-environment.nix;
          override = args: withProvider (package.override args);
          overrideAttrs = args: withProvider (package.overrideAttrs args);
        };
      outputs = pkgs.lib.genAttrs package.outputs (name: decorate package.${name} // outputs);
    in
    decorate package // outputs // { all = map (value: decorate value // outputs) package.all; };

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
    "0.27" = {
      constructor = tvp.builder;
      builder = ./native/build-0.27.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://pkg-config.freedesktop.org/releases/pkg-config-${version}.tar.gz";
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
        gettext = tvp.packages.gettext;
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnutar = constructionTool "tar";
        gzip = constructionTool "gzip";
        findutils = constructionTool "findutils";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        python = constructionTool "python";
        patch = constructionTool "patch";
        gnumake = constructionTool "make";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        diffutils = constructionTool "diffutils";
        gawk = constructionTool "gawk";
      };
      patches = [
        {
          file = ./patches/charset-directory.patch;
          reason = "Use the final base libc charset directory instead of a build prefix; preserve CHARSETALIASDIR and missing-file fallback.";
        }
      ];
      opts.cStandard = "gnu17";
    };

    "0.27.1" = {
      constructor = tvp.builder;
      builder = ./native/build-0.27.1.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://pkg-config.freedesktop.org/releases/pkg-config-${version}.tar.gz";
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
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnutar = constructionTool "tar";
        gzip = constructionTool "gzip";
        findutils = constructionTool "findutils";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        python = constructionTool "python";
        patch = constructionTool "patch";
        gnumake = constructionTool "make";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        diffutils = constructionTool "diffutils";
        gawk = constructionTool "gawk";
      };
      patches = [
        {
          file = ./patches/charset-directory.patch;
          reason = "Use the final base libc charset directory instead of a build prefix; preserve CHARSETALIASDIR and missing-file fallback.";
        }
      ];
      opts.cStandard = "gnu17";
    };

    "0.29.2" = {
      constructor = tvp.builder;
      builder = ./native/build-0.29.2.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://pkg-config.freedesktop.org/releases/pkg-config-${version}.tar.gz";
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
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnutar = constructionTool "tar";
        gzip = constructionTool "gzip";
        findutils = constructionTool "findutils";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        python = constructionTool "python";
        patch = constructionTool "patch";
        gnumake = constructionTool "make";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        diffutils = constructionTool "diffutils";
        gawk = constructionTool "gawk";
      };
      patches = [
        {
          file = ./patches/charset-directory.patch;
          reason = "Use the final base libc charset directory instead of a build prefix; preserve CHARSETALIASDIR and missing-file fallback.";
        }
      ];
      opts.cStandard = "gnu17";
    };
  };
  installedArgs = packageArgs // {
    versionTable = versionTable // {
      "0.27" = versionTable."0.27" // {
        def = if native then ownedDefs."0.27" else versionTable."0.27".def;
      };
      "0.27.1" = versionTable."0.27.1" // {
        def = if native then ownedDefs."0.27.1" else versionTable."0.27.1".def;
      };
      "0.28" = versionTable."0.28" // {
        def = if native then ownedDefs."0.27.1" else versionTable."0.28".def;
      };
      "0.29" = versionTable."0.29" // {
        def = if native then ownedDefs."0.27.1" else versionTable."0.29".def;
      };
      "0.29.1" = versionTable."0.29.1" // {
        def = if native then ownedDefs."0.27.1" else versionTable."0.29.1".def;
      };
      "0.29.2" = versionTable."0.29.2" // {
        def = if native then ownedDefs."0.29.2" else versionTable."0.29.2".def;
      };
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import
          (
            if package ? artifact && !(package.specification ? upstreamCheck) then
              ./tests/older-native-default.nix
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
        constructionRecipe.extraArgs.mkTests.override { inherit pkgs; } package
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
  canonical = pkgs.lib.mapAttrs (
    _: package: if package ? testContext then package else withProvider package
  ) (tvpLib.packages.mkVersions publicArgs);

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
