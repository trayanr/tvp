{ pkgs, tvp }:
let
  full = tvp.bases.gcc_16.full;
  variantBase = full.override {
    tools = {
      bash = tvp.packages.bash;
      coreutils = tvp.packages.coreutils;
      gnumake = tvp.packages.gnumake;
      gnutar = tvp.packages.gnutar;
      gzip = tvp.packages.gzip;
      sed = tvp.packages.gnused;
      grep = tvp.packages.gnugrep;
      diffutils = tvp.packages.diffutils;
      python = tvp.packages.python-build_3;
      patchelf = tvp.packages.patchelf_0;
    };
  };
  pname = "zstd";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.5.6-native.nix;
        deps = {
          zlib = tvp.packages.zlib_1;
          xz = tvp.packages.xz_5;

        };
      };
      releases = {
        "1.5.6" = "sha256-jCngbPQqrMHq/EB3ri7Gxvy5amJhV+BZPV6Co0/UA8E=";
      };
    }
    {
      def = {
        builder = ./build-1.5.7-native.nix;
        deps = {
          zlib = tvp.packages.zlib_1;
          xz = tvp.packages.xz_5;

        };
      };
      releases = {
        "1.5.7" = "sha256-6zPlH0mhXgI5UM14Jcp0pKK0Pbg1SCWsJPwbfuCeb6M=";
      };
    }
  ];
  testDeps = {
    gzip = tvp.packages.gzip;
    python = tvp.packages.python_3;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;

    source = tvp.lib.sources.archive {
      url =
        version: "https://github.com/facebook/zstd/releases/download/v${version}/zstd-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/facebook/zstd";
        normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else null;
        include = version: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" version != null;
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
  variants = tvp.lib.packages.mkVariants (
    family
    // {
      inherit pkgs;
      profiles.build-steps = {
        base = variantBase;
        versions."1.5.7".deps = {
          zlib = tvp.packages.zlib_1;
          xz = tvp.packages.xz_5;
          binutils = full.compiler.bintools;
        };
      };
    }
  );
in
{
  recipes."zstd" = family;
  inherit canonical;
  inherit (family) instantiate;
  inherit variants;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
