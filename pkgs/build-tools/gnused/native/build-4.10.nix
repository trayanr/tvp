# Native ordinary 4.10 route; serves 4.10 only. Retained older and
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
  acl,
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
  pname = "gnused";
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
    ];
    libraries = [ acl ];
  };
  runtime.libraries = [ acl ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz findutils;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      name = "gnused.prepare";
      inherit bash python;
      base = final.base;
    })
    (steps.shebangs {
      name = "gnused.source-shells";
      inherit python;
      paths = [
        "build-aux"
        "tests"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${bash}/bin/bash";
    })
    (command "gnused.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      ./configure --prefix="$out" --enable-nls --enable-acl
      grep '^#define ENABLE_NLS 1' config.h
    '')
    (command "gnused.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (
      (command "gnused.check" ''
        ${gnumake}/bin/make -j"$NIX_BUILD_CORES" check
      '')
      // {
        enabled = doCheck;
      }
    )
    (command "gnused.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp config.log "$out/nix-support/config.log"
      cp config.h "$out/nix-support/config.h"
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
    description = "GNU sed utilities";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
