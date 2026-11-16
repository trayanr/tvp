{ pkgs, tvp }:
let
  pname = "cmake";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-4.4.5-current.nix;
        deps = {

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
  testDeps = {
    ninja = tvp.packages.ninja;
    jsonC = tvp.packages.json-c;
    pkgConfig = tvp.packages.pkg-config;
    mpfr = tvp.packages.mpfr;
    sentinel = tvp.lib.tests.fixtures.sentinel;
    alternateSource = tvp.lib.tests.fixtures.alternateSource;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/Kitware/CMake.git";
      normalise = tag: pkgs.lib.removePrefix "v" tag;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
    };
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
  recipes."cmake" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
