{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."cmake";
  retained = prior.constructionRecipe or prior;
  earlier = import ../../../bases/source-gnu { };
  full = tvp.baseTiers.full;
  profileBase = full.override {
    shell = tvp.packages.bash_5;
    coreutils = earlier.tools.coreutils;
    standardTools = {
      python = earlier.tools.python;
      patchelf = earlier.tools.patchelf;
      gnutar = earlier.tools.tar;
      gzip = earlier.tools.gzip;
      findutils = earlier.tools.findutils;
      patch = earlier.tools.patch;
      gnumake = earlier.tools.make;
      sed = earlier.tools.sed;
      grep = earlier.tools.grep;
      diffutils = earlier.tools.diffutils;
      gawk = earlier.tools.gawk;
      pkg-config = tvp.packages.pkg-config;
    };
  };
  pname = "cmake";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-4.4.5-current.nix;
        base = profileBase;
        deps = {
          binutils = earlier.tools.binutils;
          openssl = tvp.packages.openssl;
          zlib = tvp.packages.zlib_1;
          bzip2 = tvp.packages.bzip2_1;
          xz = tvp.packages.xz_5;
          zstd = tvp.packages.zstd_1;
        };
        patches = [
          {
            file = ./patches/store-shell.patch;
            reason = "Bind generated Makefile and execute_process shell commands to the selected Bash in store-only sandboxes.";
          }
        ];
        opts = {
          docDirectory = "share/doc/cmake-4.4";
          bundledLicenseFiles = [
            "Utilities/cmliblzma/COPYING"
            "Utilities/cmzlib/Copyright.txt"
            "Utilities/cmzstd/LICENSE"
          ];
        };
      };
      releases = {
        "4.4.5" = "sha256-oMVMiKu4B43Y7MrbcX/GuxlL8Y59RMhjCZECiIhuBOI=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // {
    ninja = tvp.packages.ninja;
    jsonC = tvp.packages.json-c;
    pkgConfig = tvp.packages.pkg-config;
    mpfr = tvp.packages.mpfr;
    sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
    alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://github.com/Kitware/CMake/releases/download/v${version}/cmake-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."cmake" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
