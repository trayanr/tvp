{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  retained = import ./legacy.nix { inherit pkgs tvp; };
  constructionRecipe = retained.packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} host tool is independent of the ordinary JDK target.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "21.0.13" = {
      constructor = tvp.builder;
      builder = ./native/build-21.0.13.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        pkgs.fetchurl {
          url = "https://github.com/openjdk/jdk21u/archive/refs/tags/jdk-${version}-ga.tar.gz";
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
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        gzip = constructionTool "gzip";
        xz = constructionTool "xz";
        bzip2 = constructionTool "bzip2";
        patch = constructionTool "patch";
        findutils = constructionTool "findutils";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        which = tvp.packages.which;
        python = constructionTool "python";
        perl = constructionTool "perl";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        xorgproto = tvp.packages.xorgproto;
        libx11 = tvp.packages.libx11_1;
        libxext = tvp.packages.libxext_1;
        libxrender = tvp.packages.libxrender;
        libxtst = tvp.packages.libxtst_1;
        libxrandr = tvp.packages.libxrandr_1;
        libxt = tvp.packages.libxt_1;
        bootJdk = (
          tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "TEMURIN BINARY SEED: exact construction input for OpenJDK 21.0.13; source bootstrap remains blocked.package=jdk-bootstrap-from-source.";
          } tvp.canonical."jdk-bootstrap_21_0_13"
        );
        autoconf = tvp.packages.autoconf_2;
        zip = tvp.packages.zip;
        unzip = tvp.packages.unzip;
        file = tvp.packages.file;
        pkg-config = tvp.packages.pkg-config;
        zlib = tvp.packages.zlib_1;
        alsa = tvp.packages.alsa-lib_1;
        freetype = tvp.packages.freetype_2;
        fontconfig = tvp.packages.fontconfig_2;
        libcups = tvp.packages.libcups_2;
      };
      opts = {
        buildNumber = "9";
        dynamicLinker = "lib/ld-linux-x86-64.so.2";
      };
      patches = constructionRecipe.versionTable."21.0.13".def.patches;
    };
  };
  publicArgs = constructionRecipe // {
    versionTable = constructionRecipe.versionTable // {
      "21.0.13" = constructionRecipe.versionTable."21.0.13" // {
        def = if native then ownedDefs."21.0.13" else constructionRecipe.versionTable."21.0.13".def;
      };
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native-default.nix { inherit pkgs tvpLib package; }
      else
        (import ./legacy.nix { inherit pkgs tvp; }).packageArgs.extraArgs.mkTests package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
in
{
  recipes.jdk = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    pname = "jdk";
    versionTable = publicArgs.versionTable;
    inherit canonical;
  };
}
