{ tvp, tvpLib, candidate, defs }:
{
    "2.4.2" = defs."2.4.2" // {
      constructor = tvp.builder;
      builder = ../ordinary/build-2.4.2.nix;
      base = candidate.base;
      helpers = { inherit tvp; };
      testContext = package: tvpLib.tests.fromPackage { builder = tvp.builder; inherit package; };
      source = { version, sha256 }: import <nix/fetchurl.nix> { url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz"; inherit sha256; };
      deps = defs."2.4.2".deps // {
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
        xz = candidate.tools.xz;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
    "3.0.1" = defs."3.0.1" // {
      constructor = tvp.builder;
      builder = ../ordinary/build-2.4.2.nix;
      base = candidate.base;
      helpers = { inherit tvp; };
      testContext = package: tvpLib.tests.fromPackage { builder = tvp.builder; inherit package; };
      source = { version, sha256 }: import <nix/fetchurl.nix> { url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz"; inherit sha256; };
      deps = defs."3.0.1".deps // {
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
        xz = candidate.tools.xz;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
    "3.1.6" = defs."3.1.6" // {
      constructor = tvp.builder;
      builder = ../ordinary/build-2.4.2.nix;
      base = candidate.base;
      helpers = { inherit tvp; };
      testContext = package: tvpLib.tests.fromPackage { builder = tvp.builder; inherit package; };
      source = { version, sha256 }: import <nix/fetchurl.nix> { url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz"; inherit sha256; };
      deps = defs."3.1.6".deps // {
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
        xz = candidate.tools.xz;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
}
