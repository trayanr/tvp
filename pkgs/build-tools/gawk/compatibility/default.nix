{ tvp, tvpLib, candidate, defs }:
{
    "3.0.6" = defs."3.0.6" // {
      constructor = tvp.builder;
      builder = ../ordinary/build-3.0.6.nix;
      base = candidate.base;
      helpers = { inherit tvp; };
      testContext = package: tvpLib.tests.fromPackage { builder = tvp.builder; inherit package; };
      source = { version, sha256 }: import <nix/fetchurl.nix> { url = "https://mirrors.kernel.org/gnu/gawk/gawk-${version}.tar.gz"; inherit sha256; };
      deps = defs."3.0.6".deps // {
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
        bzip2 = candidate.tools.bzip2;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
    "3.1.8" = defs."3.1.8" // {
      constructor = tvp.builder;
      builder = ../ordinary/build-3.0.6.nix;
      base = candidate.base;
      helpers = { inherit tvp; };
      testContext = package: tvpLib.tests.fromPackage { builder = tvp.builder; inherit package; };
      source = { version, sha256 }: import <nix/fetchurl.nix> { url = "https://mirrors.kernel.org/gnu/gawk/gawk-${version}.tar.bz2"; inherit sha256; };
      deps = defs."3.1.8".deps // {
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
        bzip2 = candidate.tools.bzip2;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
}
