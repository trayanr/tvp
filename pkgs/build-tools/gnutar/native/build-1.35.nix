# Native ordinary 1.35 route; serves 1.35 only. Retained older and
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
  acl,
  attr,
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
  pname = "gnutar";
  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
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
    libraries = [
      acl
      attr
    ];
  };
  runtime.libraries = [ acl ];
  upstreamPreparation = [
    (steps.shebangs {
      name = "gnutar.source-shells";
      inherit python;
      paths = [ "tests" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
  ];
  upstreamCheck = {
    enabled = doCheck;
    before = "gnutar.install";
    command = (
      (command "gnutar.check" ''
        ${gnumake}/bin/make -j"$NIX_BUILD_CORES" check
      '')
      // {
        enabled = doCheck;
      }
    );
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz findutils;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      name = "gnutar.prepare";
      inherit python;
      bash = final.bash;
      base = final.base;
    })
    (steps.shebangs {
      name = "gnutar.source-shells";
      inherit python;
      paths = [ "build-aux" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "gnutar.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      ./configure --prefix="$out" --enable-nls --with-posix-acls --with-xattrs
      grep '^#define ENABLE_NLS 1' config.h
    '')
    (command "gnutar.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "gnutar.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp config.h "$out/nix-support/config.h"
      grep -Ex 'gt_cv_func_gnugettext[0-9]+_libc=yes' config.log > "$out/nix-support/gettext-libc"
    '')
    (steps.split "gnutar.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "gnutar.relocate";
      tools = [ python ];
      run = ''${python}/bin/python3 -B ${../../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            text = [ ];
            slots = [ ];
            fixed = [ ];
          }
        )
      } ${../../../../lib/installed-tree.py}'';
    }
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
      paths = [
        "bin"
        "libexec"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "libexec"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [
        "bin"
        "libexec"
      ];
      elfKinds = [ "runtime" ];
    })
  ];
  meta = {
    description = "GNU tar utilities";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
