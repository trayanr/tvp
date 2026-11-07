# Native ordinary 9.5 route; serves 9.5 only. Retained older and
# construction procedures keep their own host generations and feature profiles.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnumake,
  gnutar,
  xz,
  python,
  perl,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  gmp,
  acl,
  timezoneData,
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
in
final:
let
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
in
{
  pname = "coreutils";
  inherit
    base
    src
    version
    bash
    ;
  coreutils = coreutils;
  environment = {
    tools = [
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
      perl
      python
      xz
      acl
    ];
    libraries = [
      gmp
      acl
    ];
  };
  runtime.libraries = [
    gmp
    acl
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz findutils;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      name = "coreutils.prepare";
      inherit python;
      bash = final.bash;
      base = final.base;
    })
    (steps.shebangs {
      name = "coreutils.source-shells";
      inherit python;
      paths = [
        "build-aux"
        "tests"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "coreutils.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      ./configure --prefix="$out" --enable-nls --with-gmp --enable-acl --without-selinux
      grep '^#define ENABLE_NLS 1' lib/config.h
      grep '^#define USE_ACL 1' lib/config.h
      grep '^#define HAVE_GMP_H 1' lib/config.h
    '')
    (command "coreutils.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (
      (command "coreutils.check" ''
            export TZDIR=${timezoneData}/share/zoneinfo
        "$CC" ${../../../../lib/tests/filesystem-capabilities.c} -o .tvp-filesystem-probe
          ${gnumake}/bin/make -j"$NIX_BUILD_CORES" check \
            SH_LOG_COMPILER="${python}/bin/python3 -B ${../../../../lib/tests/ordinary-test-runner.py} coreutils $PWD/.tvp-filesystem-probe ${final.bash}/bin/bash"
      '')
      // {
        enabled = doCheck;
      }
    )
    (command "coreutils.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp config.log "$out/nix-support/config.log"
      cp lib/config.h "$out/nix-support/config.h"
    '')
    (outputs.strip {
      inherit python binutils;
      paths = [ "bin" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [ "bin" ];
      elfKinds = [ "runtime" ];
    })
  ];
  meta = {
    description = "GNU coreutils utilities";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
