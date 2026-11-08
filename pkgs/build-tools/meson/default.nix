{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.11.1" = {
      builder = ./build-1.11.1.nix;
      base = tvp.bases.default;
      deps = {
        python = tvp.packages.python-build_3;
        bash = tvp.packages.bash_5;
        ninja = tvp.packages.ninja;
        cmake = tvp.packages.cmake;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/store-rpaths.patch;
          reason = "Store-layout adaptation: retain immutable Nix store library RPATHs during installation; Meson otherwise removes paths added by the owned compiler wrapper and installed shared-library consumers fail to load.";
        }
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.11.1";
      releases = {
        "1.11.1" = "sha256-Z4iuKZl5ZD+NhBvK9kNSVYQ2yuRaA1UUijruzPeROGY=";
        "1.11.2" = "sha256-aY/q4GnO8+zU16rygdffNZvfz1VamhVkOD07kT+opzY=";
        "1.12.0" = "sha256-iK/gwg5SAwIYkkrDfQyBxZtLXzrjdSyMbXRwx9NliGw=";
        "1.12.1" = "sha256-qwpsoJ+O9wxWTIJB+1ojlXiGoLU/tYQSteB+rwfbp0M=";
      };
    }
  ];
  pname = "meson";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;
        zlib = tvp.packages.zlib_1;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      }
    ) { inherit pkgs; };
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/mesonbuild/meson.git";
      normalise = tag: tag;
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
    "1.12.1" = {
      constructor = tvp.builder;
      builder = ./native/build-1.12.1.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://github.com/mesonbuild/meson/releases/download/${version}/meson-${version}.tar.gz";
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
        helperPython = constructionTool "python";
        patch = constructionTool "patch";
        python = tvp.packages.python_3;
        bash = tvp.packages.bash_5;
        ninja = tvp.packages.ninja;
        cmake = tvp.packages.cmake;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/store-rpaths.patch;
          reason = "Retain immutable store library RPATHs when installing native consumers.";
        }
      ];

    };
  };
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "1.12.1" = versionTable."1.12.1" // {
        def = if native then ownedDefs."1.12.1" else versionTable."1.12.1".def;
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
  canonical = tvpLib.packages.mkVersions publicArgs;

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
