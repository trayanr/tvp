{ tvp, tvpLib, candidate, defs }:
{
    "5.0.5" = defs."5.0.5" // {
      constructor = tvp.builder;
      builder = ../ordinary/build-5.0.5.nix;
      base = candidate.base;
      helpers = { inherit tvp; };
      testContext = package: tvpLib.tests.fromPackage { builder = tvp.builder; inherit package; };
      source = { version, sha256 }: import <nix/fetchurl.nix> { url = "https://mirrors.kernel.org/gnu/gmp/gmp-${version}.tar.xz"; inherit sha256; };
      deps = defs."5.0.5".deps // {
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
        m4 = candidate.tools.m4;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
    "5.1.3" = defs."5.0.5" // {
      constructor = tvp.builder;
      builder = ../ordinary/build-5.0.5.nix;
      base = candidate.base;
      helpers = { inherit tvp; };
      testContext = package: tvpLib.tests.fromPackage { builder = tvp.builder; inherit package; };
      source = { version, sha256 }: import <nix/fetchurl.nix> { url = "https://mirrors.kernel.org/gnu/gmp/gmp-${version}.tar.xz"; inherit sha256; };
      deps = defs."5.0.5".deps // {
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
        m4 = candidate.tools.m4;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
    "6.0.0a" = defs."6.0.0a" // {
      constructor = tvp.builder;
      builder = ../ordinary/build-5.0.5.nix;
      base = candidate.base;
      helpers = { inherit tvp; };
      testContext = package: tvpLib.tests.fromPackage { builder = tvp.builder; inherit package; };
      source = { version, sha256 }: import <nix/fetchurl.nix> { url = "https://mirrors.kernel.org/gnu/gmp/gmp-${version}.tar.xz"; inherit sha256; };
      deps = defs."6.0.0a".deps // {
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
        m4 = candidate.tools.m4;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
}
