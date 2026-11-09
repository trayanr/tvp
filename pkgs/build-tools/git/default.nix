{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  retained = previous.recipes.git.constructionRecipe;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is a build-only provider independent of ordinary frontends.";
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "2.56.0" = {
      constructor = tvp.builder;
      builder = ./native/build-2.56.0.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://www.kernel.org/pub/software/scm/git/git-${version}.tar.xz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        rustc = tvp.packages.rustc_1;
        cargo = tvp.packages.cargo-bootstrap_1;
        pkg-config = tvp.packages.pkg-config;
        bash = tvp.packages.bash;
        perl = tvp.packages.perl_5;
        python = tvp.packages.python_3;
        curl = tvp.packages.curl;
        openssl = tvp.packages.openssl;
        zlib = tvp.packages.zlib;
        expat = tvp.packages.expat;
        pcre2 = tvp.packages.pcre2;
        coreutils = tvp.packages.coreutils;
        gnumake = tvp.packages.gnumake;
        gnutar = tvp.packages.gnutar;
        xz = tvp.packages.xz;
        findutils = tvp.packages.findutils;
        diffutils = tvp.packages.diffutils;
        gawk = tvp.packages.gawk;
        gnused = tvp.packages.gnused;
        gnugrep = tvp.packages.gnugrep;
        binutils = tvp.packages.binutils;
        patchelf = tvp.packages.patchelf;
        helperPython = constructionTool "python";
      };

    };
  };
  versionTable = retained.versionTable // {
    "2.56.0" = retained.versionTable."2.56.0" // {
      def = if native then defs."2.56.0" else retained.versionTable."2.56.0".def;
    };
  };
  publicArgs = retained // {
    inherit versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix {
          inherit
            pkgs
            tvp
            tvpLib
            package
            ;
        }
      else
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "git";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
