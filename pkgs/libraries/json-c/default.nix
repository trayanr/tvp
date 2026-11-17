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
      cmake = tvp.packages.cmake;
      patch = tvp.packages.patch;
    };
  };
  pname = "json-c";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-0.19-native.nix;
        patches = [
          {
            file = ./patches/posix-test-byte.patch;
            reason = "Emit the same incomplete UTF-8 byte with POSIX printf instead of undeclared xxd in the upstream CLI fixture.";
          }
        ];
      };
      releases = {
        "0.19" = "sha256-N60CSZAuMBvZBSv3EuUR/Mas/07KrUtZAKrZzlZOJt4=";
      };
    }
  ];
  testDeps = {
    pkg-config = tvp.packages.pkg-config;
    cmake = tvp.packages.cmake;
    grep = tvp.packages.gnugrep;
    diffutils = tvp.packages.diffutils;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;

    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/json-c/json-c/releases/download/json-c-${version}-20260627/json-c-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/json-c/json-c.git";
        normalise =
          tag:
          let
            m = builtins.match "json-c-([0-9]+[.][0-9]+([.][0-9]+)?)-[0-9]{8}" tag;
          in
          if m == null then null else builtins.head m;
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
        versions."0.19".deps = {
          binutils = full.compiler.bintools;
        };
      };
    }
  );
in
{
  recipes."json-c" = family;
  inherit canonical;
  inherit (family) instantiate;
  inherit variants;
  aliases = tvp.lib.packages.mkAliases {
    inherit pname versionTable canonical;
    lines = [ "0" ];
  };
}
