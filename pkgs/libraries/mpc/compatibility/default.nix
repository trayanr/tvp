{ tvp, tvpLib, candidate, defs }:
{
    "1.0.3" = defs."1.0.3" // {
      constructor = tvp.builder;
      builder = ../ordinary/build-1.0.3.nix;
      base = candidate.base;
      helpers = { inherit tvp; };
      testContext = package: tvpLib.tests.fromPackage { builder = tvp.builder; inherit package; };
      source = { version, sha256 }: import <nix/fetchurl.nix> { url = "https://mirrors.kernel.org/gnu/mpc/mpc-${version}.tar.gz"; inherit sha256; };
      deps = defs."1.0.3".deps // {
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
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
}
