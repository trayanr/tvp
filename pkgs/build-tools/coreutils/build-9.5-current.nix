# Native ordinary 9.5 route; serves 9.5 only. Retained older and
# construction procedures keep their own host generations and feature profiles.
{
  tvp,
  lib,
  base,
  src,
  version,
  binutils,
  gmp,
  acl,
  timezoneData,
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs;
  baseTools = context.tools;
  bash = baseTools.bash;
  coreutils = baseTools.coreutils;
  diffutils = baseTools.diffutils;
  findutils = baseTools.findutils;
  gawk = baseTools.gawk;
  gnumake = baseTools.gnumake;
  gnutar = baseTools.gnutar;
  grep = baseTools.grep;
  gzip = baseTools.gzip;
  patchelf = baseTools.patchelf;
  perl = baseTools.perl;
  python = baseTools.python;
  sed = baseTools.sed;
  xz = baseTools.xz;
in

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
  bash = baseTools.bash;
  coreutils = baseTools.coreutils;
  diffutils = baseTools.diffutils;
  findutils = baseTools.findutils;
  gawk = baseTools.gawk;
  gnumake = baseTools.gnumake;
  gnutar = baseTools.gnutar;
  grep = baseTools.grep;
  gzip = baseTools.gzip;
  patchelf = baseTools.patchelf;
  perl = baseTools.perl;
  python = baseTools.python;
  sed = baseTools.sed;
  xz = baseTools.xz;
  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    ;
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
  upstreamPreparation = [
    (steps.shebangs {
      name = "coreutils.source-shells";
      inherit python;
      paths = [ "tests" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
  ];
  doCheck = doCheck;
  timezoneData = timezoneData;
  upstreamCheck =
    (command "coreutils.check" ''
      export TZDIR=${final.timezoneData}/share/zoneinfo
      "$CC" ${../../../lib/tests/filesystem-capabilities.c} -o .tvp-filesystem-probe
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" check \
        SH_LOG_COMPILER="${python}/bin/python3 -B ${../../../lib/tests/ordinary-test-runner.py} coreutils $PWD/.tvp-filesystem-probe ${final.bash}/bin/bash"
    '')
    // {
      enabled = final.doCheck;
    };

  originalPlan = steps.sequence [
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
      paths = [ "build-aux" ];
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
    (command "coreutils.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp lib/config.h "$out/nix-support/config.h"
      grep -Ex 'gt_cv_func_gnugettext[0-9]+_libc=yes' config.log > "$out/nix-support/gettext-libc"
    '')
    (steps.split "coreutils.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "coreutils.relocate";
      tools = [ python ];
      run = ''${python}/bin/python3 -B ${../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            text = [ ];
            slots = [ ];
            fixed = [ ];
          }
        )
      } ${../../../lib/installed-tree.py}'';
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
    description = "GNU coreutils utilities";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };

  upstreamPlan = artifact: [
    {
      name = "coreutils.restore-build-tree";
      tools = [ baseTools.python ];
      run = ''
        ${baseTools.python}/bin/python3 -B ${../current-restore.py} ${artifact}/nix-support/coreutils-build-tree "$TVP_SOURCE_ROOT"
      '';
    }
    {
      name = "coreutils.prepare-tests";
      tools = [ baseTools.python ];
      run = ''
        cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        ${lib.concatMapStringsSep "\n" (step: step.run) final.upstreamPreparation}
      '';
    }
  ];
  plan =
    let
      parts = steps.partition final.originalPlan;
    in
    parts.first
    ++ [
      {
        name = "coreutils.save-build-tree";
        tools = [
          baseTools.python
          final.coreutils
        ];
        run = ''
          ${baseTools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/nix-support/coreutils-build-tree"
        '';
      }
    ]
    ++ (lib.optional parts.split (steps.split "coreutils.finalize"))
    ++ [
      (builtins.head parts.second)
      {
        name = "coreutils.drop-build-tree";
        tools = [ final.coreutils ];
        run = ''${final.coreutils}/bin/rm -rf -- "$out/nix-support/coreutils-build-tree"'';
      }
    ]
    ++ builtins.tail parts.second;
}
