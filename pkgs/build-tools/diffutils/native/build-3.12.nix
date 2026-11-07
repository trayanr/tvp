# Native ordinary 3.12 route; serves 3.12 only. Retained older and
# construction procedures keep their own host generations and feature profiles.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  buildCoreutils,
  gnumake,
  gnutar,
  xz,
  gzip,
  python,
  perl,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  coreutils,
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
  pname = "diffutils";
  inherit
    base
    src
    version
    bash
    ;
  coreutils = buildCoreutils;
  helperCoreutils = coreutils;
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
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz findutils;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      name = "diffutils.prepare";
      inherit python;
      bash = final.bash;
      base = final.base;
    })
    (steps.shebangs {
      name = "diffutils.source-shells";
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
    (command "diffutils.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      export PR_PROGRAM=${final.helperCoreutils}/bin/pr
      ./configure --prefix="$out" --enable-nls
      grep '^#define ENABLE_NLS 1' lib/config.h
    '')
    (command "diffutils.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (
      (command "diffutils.check" ''
        ${gnumake}/bin/make -j"$NIX_BUILD_CORES" check
      '')
      // {
        enabled = doCheck;
      }
    )
    (command "diffutils.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp lib/config.h "$out/nix-support/config.h"
    '')
    {
      name = "output.manuals";
      tools = [
        gzip
        findutils
      ];
      run = ''
        while IFS= read -r -d "" manual; do
          ${gzip}/bin/gzip -n -9 "$manual"
        done < <(${findutils}/bin/find "$out/share/man" -type f ! -name '*.gz' -print0)
        while IFS= read -r -d "" manual; do
          target=$(readlink "$manual")
          rm "$manual"
          ln -s "$target.gz" "$manual.gz"
        done < <(${findutils}/bin/find "$out/share/man" -type l ! -name '*.gz' -print0)
      '';
    }
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
    description = "GNU diffutils utilities";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
