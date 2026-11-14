{ tvp, tvpLib, candidate, defs }:
{
    "2.3.0" = defs."2.3.0" // {
      constructor = tvp.builder;
      builder = ../ordinary/build-2.3.0.nix;
      base = tvp.bases.gcc13-owned-v3;
      helpers = { inherit tvp; };
      testContext = package: tvpLib.tests.fromPackage { builder = tvp.builder; inherit package; };
      source = { version, sha256 }: import <nix/fetchurl.nix> { url = "https://download.savannah.nongnu.org/releases/acl/acl-${version}.tar.gz"; inherit sha256; };
      deps = defs."2.3.0".deps // {
        bash = candidate.tools.bash;
        coreutils = candidate.tools.coreutils;
        python = candidate.tools.python;
        binutils = candidate.tools.binutils;
        patchelf = candidate.tools.patchelf;
        sed = candidate.tools.sed;
        grep = candidate.tools.grep;
        gawk = candidate.tools.gawk;
        diffutils = candidate.tools.diffutils;
        findutils = candidate.tools.findutils;
        gzip = candidate.tools.gzip;
        perl = candidate.tools.perl;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
    "2.3.1" = defs."2.3.0" // {
      constructor = tvp.builder;
      builder = ../ordinary/build-2.3.0.nix;
      base = tvp.bases.gcc13-owned-v3;
      helpers = { inherit tvp; };
      testContext = package: tvpLib.tests.fromPackage { builder = tvp.builder; inherit package; };
      source = { version, sha256 }: import <nix/fetchurl.nix> { url = "https://download.savannah.nongnu.org/releases/acl/acl-${version}.tar.gz"; inherit sha256; };
      deps = defs."2.3.0".deps // {
        bash = candidate.tools.bash;
        coreutils = candidate.tools.coreutils;
        python = candidate.tools.python;
        binutils = candidate.tools.binutils;
        patchelf = candidate.tools.patchelf;
        sed = candidate.tools.sed;
        grep = candidate.tools.grep;
        gawk = candidate.tools.gawk;
        diffutils = candidate.tools.diffutils;
        findutils = candidate.tools.findutils;
        gzip = candidate.tools.gzip;
        perl = candidate.tools.perl;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
}
