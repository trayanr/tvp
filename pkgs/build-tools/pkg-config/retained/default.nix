# Exact historical stdenv construction family. Never wrap in the owned constructor.
{ pkgs, tvp }:
let

  defs = tvp.lib.packages.mkDefs {
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
                (import ../../../runtimes/jdk-bootstrap/legacy.nix { inherit pkgs tvp; })
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

  versionTable = tvp.lib.packages.mkTable (import ./releases.nix { inherit defs; });

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
        import ../tests/retained.nix {
          inherit pkgConfig;
          tvpLib = tvp.lib;
          pkgs = tvp.lib.tests.withBase {
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

in
packageArgs
