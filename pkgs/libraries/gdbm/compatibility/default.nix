{ tvp, tvpLib, candidate, defs }:
{
    "1.7.3" = defs."1.7.3" // {
      constructor = tvp.builder;
      builder = ../ordinary/build-1.7.3.nix;
      base = candidate.base;
      helpers = { inherit tvp; };
      testContext = package: tvpLib.tests.fromPackage { builder = tvp.builder; inherit package; };
      source = { version, sha256 }: import <nix/fetchurl.nix> { url = "https://mirrors.kernel.org/gnu/gdbm/gdbm-${version}.tar.gz"; inherit sha256; };
      deps = defs."1.7.3".deps // {
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
        pkgConfig = candidate.tools.pkgConfig;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
        file = tvp.packages.file;
      };
      opts = defs."1.7.3".opts // {
        preparation = {
          selections = [ "configure" ];
          libtoolAnchors = { };
          edits = [ ];
        };
      };
    };
    "1.8.1" = defs."1.8.1" // {
      constructor = tvp.builder;
      builder = ../ordinary/build-1.7.3.nix;
      base = candidate.base;
      helpers = { inherit tvp; };
      testContext = package: tvpLib.tests.fromPackage { builder = tvp.builder; inherit package; };
      source = { version, sha256 }: import <nix/fetchurl.nix> { url = "https://mirrors.kernel.org/gnu/gdbm/gdbm-${version}.tar.gz"; inherit sha256; };
      deps = defs."1.8.1".deps // {
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
        pkgConfig = candidate.tools.pkgConfig;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
        file = tvp.packages.file;
      };
      opts = defs."1.8.1".opts // {
        preparation = {
          selections = [ "configure" "config.sub" "config.guess" "install-sh" "mkinstalldirs" "ltmain.sh" ];
          libtoolAnchors = { "ltmain.sh" = 1; };
          edits = [ { path = "Makefile.in"; before = " -o $(BINOWN) -g $(BINGRP)"; after = ""; count = 5; } ];
        };
      };
    };
}
