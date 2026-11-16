{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
      };
      status = {
        level = "broken";
        reason = "The bundled gnulib tests SIGSTKSZ in a preprocessor conditional (lib/c-stack.c), and glibc 2.34 redefined it from a constant to a sysconf() call, so the file no longer preprocesses.";
        needs = "A period glibc (< 2.34). The code was correct when released; the substrate moved under it. Upstream's own fix was a full gnulib rewrite that arrived in 1.4.19, not a change TVP can apply backwards.";
        blocked.package = "glibc<2.34";
      };
      releases = {
        "1.4.17" = "sha256-POclEz7lUri0usp4N/t3KUCyXoGyqdySU3rq9zNTjJ4=";
        "1.4.18" = "sha256-qyYzkhpc045IeXv1UhrSWb3EuXkHgDSjt5DX/sVJP6s=";
      };
    }
    {
      def = {
        builder = ./build.nix;
        # Bundled gnulib's C23 attribute placement is fixed in 1.4.20.
        opts.cStandard = "gnu17";
      };
      releases."1.4.19" = "sha256-O+SibYJf/f2lKlb8QyRkVpiaNjAJPM7T+930dx7linA=";
    }
    {
      def = {
        builder = ./build.nix;
      };
      releases = {
        "1.4.20" = "sha256-asT8Mc5EDevmOYfC67+de2Y05np8Mnklfcc2Hei9s+8=";
        "1.4.21" = "sha256-OK5Z96ML+cEIGTzFwl+7BgFPIeIwx+3i7/YU97fDftg=";
      };
    }
  ];
  pname = "m4";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/m4/";
      pattern = "m4-[0-9][^\"]*\\.tar\\.gz";
      normalise = tvp.lib.versions.fromArchiveName {
        prefix = "m4-";
        suffixes = [ ".tar.gz" ];
      };
      include = version: builtins.match "[0-9].*" version != null;
    };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/m4/m4-${version}.tar.gz";
        inherit sha256;
      };
    # These are test-only choices. They never participate in production defaults.
    testDeps = {
      runtimeShell = tvp.packages.bash_5;
      alternateCoreutils = tvp.packages.coreutils;
      pkgConfig = tvp.packages.pkg-config;
      mpfr = tvp.packages.mpfr;
      sentinel = tvp.lib.tests.fixtures.sentinel;
      alternateSource = tvp.lib.tests.fixtures.alternateSource;
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.m4 = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases {
    inherit pname canonical;
    inherit versionTable;
  };
}
