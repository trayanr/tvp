{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          meson = tvp.packages.meson;
          ninja = tvp.packages.ninja;
          gperf = tvp.packages.gperf;
          pkg-config = tvp.packages.pkg-config;
          freetype = tvp.packages.freetype_2;
          expat = tvp.packages.expat_2;
        };
      };
      releases."2.18.3" = "sha256-T3tVSjjN94wDP2ZsiHHzdJ4UoJT2Wgf2MMke0LQ9NeM=";
    }
  ];
  pname = "fontconfig";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/${version}/fontconfig-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests/owned.nix;

  };
  profileFamily = tvp.lib.packages.mkFamily {
    inherit pname;
    versionTable = tvp.lib.packages.mkTable [
      {
        def = {
          builder = ./public-build-steps.nix;
          deps = {
            meson = tvp.packages.meson;
            ninja = tvp.packages.ninja;
            gperf = tvp.packages.gperf;
            pkg-config = tvp.packages.pkg-config;
            freetype = tvp.packages.freetype_2;
            expat = tvp.packages.expat_2;
          };
        };
        releases."2.18.3" = "sha256-T3tVSjjN94wDP2ZsiHHzdJ4UoJT2Wgf2MMke0LQ9NeM=";
      }
    ];
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/${version}/fontconfig-${version}.tar.xz";
        inherit sha256;
      };
    testDeps.python = tvp.packages.python_3;
    # Closure expectations are an independent consumer of the effective output.
    tests =
      {
        package,
        lib,
        context,
      }:
      (import ./tests/owned.nix { inherit package lib context; })
      // {
        upstream = import ./tests/profile-upstream.nix { inherit package lib context; };
        runtime-expectation = import ../../../lib/runtime-expectation.nix { inherit lib; } {
          inherit package;
          inherit context;
          python = package.tvp.declaredTestDependencies.python;
        };
      };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.fontconfig = family;
  inherit canonical;
  inherit (family) instantiate;
  variants.build-steps = pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
    fontconfig_2_18_3 = tvp.lib.packages.tagSelection {
      namespace = "variants.build-steps";
      selector = "fontconfig_2_18_3";
      kind = "variant";
      pname = "fontconfig";
      version = "2.18.3";
      canonical = "fontconfig_2_18_3";
    } ((tvp.lib.packages.mkVersions (profileFamily // { variant = "build-steps"; })).fontconfig_2_18_3);
  };
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
