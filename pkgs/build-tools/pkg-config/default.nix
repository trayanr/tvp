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
        gettext = tvp.packages.gettext;
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
  canonical = pkgs.lib.mapAttrs (_: withProvider) (tvpLib.packages.mkVersions packageArgs);

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    inherit
      pname
      versionTable
      canonical
      ;
  };
}
