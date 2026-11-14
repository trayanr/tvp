{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.5.6" = {
      builder = ./build-1.5.6.nix;
      base = tvp.bases.default;
      deps = {
        zlib = tvp.packages.zlib_1;
        xz = tvp.packages.xz_5;
      };
    };
    "1.5.7" = {
      constructor = tvp.builder;
      builder = ./legacy/build-1.5.7.nix;
      helpers = {
        inherit tvp;
      };
      base = tvp.bases.default;
      deps = {
        inherit (tvp.packages)
          bash
          coreutils
          gnutar
          gzip
          gnumake
          gnused
          gnugrep
          diffutils
          ;
        python = tvp.packages.python-build_3;
        # Use the selected base toolchain: public Binutils itself consumes Zstd.
        binutils = tvp.bases.default.stdenv.cc.bintools.bintools;
        patchelf = tvp.packages.patchelf_0;
        zlib = tvp.packages.zlib_1;
        xz = tvp.packages.xz_5;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.5.6";
      releases = {
        "1.5.6" = "sha256-jCngbPQqrMHq/EB3ri7Gxvy5amJhV+BZPV6Co0/UA8E=";

      };
    }
    {
      def = defs."1.5.7";
      releases."1.5.7" = "sha256-6zPlH0mhXgI5UM14Jcp0pKK0Pbg1SCWsJPwbfuCeb6M=";
    }
  ];
  source =
    { version, sha256 }:
    pkgs.fetchurl {
      url = "https://github.com/facebook/zstd/releases/download/v${version}/zstd-${version}.tar.gz";
      inherit sha256;
    };
  pname = "zstd";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    testDeps = {
      gzip = tvp.packages.gzip;
    };

    extraArgs.mkTests =
      zstd:
      import ./tests {
        inherit pkgs tvpLib zstd;
        inherit (zstd.tvp.declaredTestDependencies) gzip;
      }
      // pkgs.lib.optionalAttrs (zstd ? edit) {
        helpers = import ./tests/helpers.nix {
          package = zstd;
          inherit (zstd.tvp.deps) bash coreutils gnugrep;
        };
      };
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/facebook/zstd";
      normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else null;
      include = version: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" version != null;
    };
  };
  publicArgs = packageArgs // {
    inherit source;
  };
  # Retain the complete pre-migration recipe for historical test construction.
  constructionRecipe = packageArgs // {
    versionTable = versionTable // {
      "1.5.7" = versionTable."1.5.7" // {
        def = defs."1.5.6";
      };
    };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  inherit publicArgs;
  variants.build-steps = pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
    zstd_1_5_7 = tvp.builder {
      recipe = import ./build-steps-1.5.7.nix;
      args = {
        inherit (pkgs) lib;
        inherit tvp;
        base = tvp.bases.default;
        version = "1.5.7";
        src = source {
          version = "1.5.7";
          inherit (versionTable."1.5.7") sha256;
        };
        inherit (tvp.packages)
          bash
          coreutils
          gnutar
          gzip
          gnumake
          gnused
          gnugrep
          diffutils
          ;
        python = tvp.packages.python-build_3;
      } // defs."1.5.7".deps;
      dependencyNames = [
        "bash"
        "coreutils"
        "gnutar"
        "gzip"
        "gnumake"
        "gnused"
        "gnugrep"
        "diffutils"
        "python"
        "binutils"
        "patchelf"
        "zlib"
        "xz"
      ];
      infrastructure = packageArgs.infra;
      metadata = {
        status.level = "ok";
        canonical = false;
        variant = "build-steps";
        builder = "build-steps-1.5.7.nix";
        definition = "1.5.7";
        declaredTestDependencies = {
          inherit (tvp.packages) gzip gnugrep;
          python = tvp.packages.python_3;
        };
      };
      selection = {
        namespace = "variants.build-steps";
        selector = "zstd_1_5_7";
        kind = "variant";
        pname = "zstd";
        version = "1.5.7";
        canonical = "zstd_1_5_7";
      };
      mkTests =
        zstd:
        packageArgs.extraArgs.mkTests zstd
        // {
          helpers = import ./tests/helpers.nix {
            package = zstd;
            inherit (zstd.tvp.deps) bash coreutils gnugrep;
          };
          runtime-expectation = import ../../../lib/runtime-expectation.nix { inherit (pkgs) lib; } {
            package = zstd;
            stdenv = zstd.stdenv;
            python = tvp.packages.python_3;
          };
        };
    };
  };
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
