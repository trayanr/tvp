{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  constructionRecipe = previous.recipes.autoconf;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  host =
    name: reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    } candidate.tools.${name};
  defs = tvpLib.packages.mkDefs {
    "2.73" = {
      constructor = tvp.builder;
      builder = ./native/build-2.73.nix;
      base = candidate.base;
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
        m4 = tvp.packages.m4_1;
        perl = tvp.packages.perl_5;
        bash = tvp.packages.bash_5;
        coreutils = tvp.packages.coreutils_9;
        gnumake = tvp.packages.gnumake_4;
        gnutar = tvp.packages.gnutar_1;
        gzip = tvp.packages.gzip_1;
        findutils = tvp.packages.findutils_4;
        sed = tvp.packages.gnused_4;
        grep = tvp.packages.gnugrep_3;
        gawk = tvp.packages.gawk_5;
        diffutils = tvp.packages.diffutils_3;
        python = host "python" "Independent source/output helper avoids public Python -> pkg-config -> Autoconf.";
      };
    };
  };
  versionTable = constructionRecipe.versionTable // {
    "2.73" = constructionRecipe.versionTable."2.73" // {
      def = if native then defs."2.73" else constructionRecipe.versionTable."2.73".def;
    };
  };
  publicArgs = constructionRecipe // {
    inherit versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        urls = [
          "https://mirrors.kernel.org/gnu/autoconf/autoconf-${version}.tar.gz"
          "https://ftp.gnu.org/gnu/autoconf/autoconf-${version}.tar.gz"
        ];
        inherit sha256;
      };
    testDeps = {
      automake = tvp.packages.automake_1;
      libtool = tvp.packages.libtool_2;
      alternatePerl = candidate.tools.perl;
      alternateM4 = candidate.tools.m4;
      runtimeShell = candidate.tools.bash;
      python = candidate.tools.python;
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
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
        constructionRecipe.extraArgs.mkTests.override { inherit pkgs; } package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "autoconf";
in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    lines = [ "2_13" ];
    inherit pname versionTable canonical;
  };
}
