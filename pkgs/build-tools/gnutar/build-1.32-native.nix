# GNU Tar 1.32–1.34: complete ordinary procedure. All three release archives
# have the same generated Autotools/gnulib layout; PAX fixture semantics vary.
{
  tvp,
  lib,
  base,
  src,
  version,
  binutils,
  acl,
  attr,
  doCheck ? true,
}:

final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs;
  baseTools = context.tools;
  inherit (final)
    bash
    coreutils
    gnumake
    gnutar
    gzip
    xz
    sed
    grep
    gawk
    diffutils
    findutils
    python
    perl
    patchelf
    ;
  environment = final.base.environment final.environment;
  productionMake =
    target:
    lib.concatMapStringsSep "\n"
      (
        directory:
        let
          noTestRecursion = lib.optionalString (directory == ".") " SUBDIRS=.";
        in
        ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" -C ${lib.escapeShellArg directory} SHELL=${final.bash}/bin/bash ${target}${noTestRecursion}''
      )
      [
        "doc"
        "gnu"
        "lib"
        "rmt"
        "src"
        "scripts"
        "po"
        "."
      ];
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
  bash = baseTools.bash;
  coreutils = baseTools.coreutils;
  gnumake = baseTools.gnumake;
  gnutar = baseTools.gnutar;
  gzip = baseTools.gzip;
  xz = baseTools.xz;
  sed = baseTools.sed;
  grep = baseTools.grep;
  gawk = baseTools.gawk;
  diffutils = baseTools.diffutils;
  findutils = baseTools.findutils;
  python = baseTools.python;
  perl = baseTools.perl;
  patchelf = baseTools.patchelf;

  inherit
    base
    src
    version
    ;
  inherit
    binutils
    acl
    attr
    doCheck
    ;
  features = {
    nls = true;
    acls = true;
    xattrs = true;
  };
  configureFlags = [
    (if final.features.nls then "--enable-nls" else "--disable-nls")
    (if final.features.acls then "--with-posix-acls" else "--without-posix-acls")
    (if final.features.xattrs then "--with-xattrs" else "--without-xattrs")
  ];
  stripFlags = [
    "-S"
    "-p"
  ];
  dependencyProviders = {
    binutils = final.binutils;
    acl = final.acl;
    attr = final.attr;
  };
  environment = {
    tools = [
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.perl
    ];
    libraries = [
      final.acl
      final.attr
    ];
  };
  runtime.shell = final.bash;
  runtime.tools = [
    final.coreutils
    final.sed
    final.grep
    final.gawk
    final.diffutils
    final.findutils
  ];
  runtime.libraries = [ final.acl ];
  upstreamCheck =
    (builtins.head (
      builtins.filter (
        step: step.name == "gnutar.check" || step.name == "gnutar.check-upstream" || step.name == "check"
      ) (steps.partition final.originalPlan).first
    ))
    // {
      enabled = final.doCheck;
    };
  originalPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      xz = final.xz;
      findutils = final.findutils;
      tar = final.gnutar;
    })
    (command "gnutar.prepare" ''
      ${final.python}/bin/python3 -B ${./ordinary/source.py} ${final.bash}/bin/bash ${final.perl}/bin/perl '["build-aux","scripts"]'
    '')
    (command "gnutar.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
      ${lib.optionalString final.features.nls "grep '^#define ENABLE_NLS 1' config.h"}
      ${lib.optionalString final.features.acls "grep -F '#define HAVE_POSIX_ACLS /**/' config.h"}
      ${lib.optionalString final.features.xattrs "grep -F '#define HAVE_XATTRS /**/' config.h"}
    '')
    (command "gnutar.build" (productionMake "all"))
    (
      (command "gnutar.check" ''
        status=0
        ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" check || status=$?
        cat tests/testsuite.log
        exit "$status"
      '')
      // {
        enabled = final.doCheck;
      }
    )
    (command "gnutar.install" ''
      ${productionMake "install"}
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp config.h "$out/nix-support/config.h"
      ${lib.optionalString final.features.nls "grep -Ex 'gt_cv_func_gnugettext[0-9]+_libc=yes' config.log > \"$out/nix-support/gettext-libc\""}
    '')
    (steps.split "gnutar.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "gnutar.relocate";
      tools = [
        final.python
        final.binutils
        final.patchelf
      ];
      run = ''${final.python}/bin/python3 -B ${./ordinary/output.py} "$out" "$TVP_ARTIFACT_ROOT" ${final.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            readelf = "${final.binutils}/bin/readelf";
            shell = "${final.runtime.shell}/bin/bash";
            buildShell = "${final.bash}/bin/bash";
            paths = map (p: "${p}/bin") final.runtime.tools;
            requiredDirectories = [
              "bin"
              "libexec"
              "share/man"
              "nix-support"
            ];
            requiredFiles = [
              "bin/tar"
              "libexec/rmt"
            ];
            requiredRegular = [
              "bin/tar"
              "libexec/rmt"
            ];
          }
        )
      }'';
    }
    {
      name = "output.manuals";
      tools = [
        final.gzip
        final.findutils
      ];
      run = ''
        while IFS= read -r -d "" manual; do
          ${final.gzip}/bin/gzip -n -9 "$manual"
        done < <(${final.findutils}/bin/find "$out/share/man" -type f ! -name '*.gz' -print0)
        while IFS= read -r -d "" manual; do
          target=$(readlink "$manual")
          rm "$manual"
          ln -s "$target.gz" "$manual.gz"
        done < <(${final.findutils}/bin/find "$out/share/man" -type l ! -name '*.gz' -print0)
      '';
    }
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      flags = final.stripFlags;
      paths = [
        "bin"
        "libexec"
      ];
      elfKinds = [ "runtime" ];
    })
    ((import ./ordinary/rpaths.nix { inherit lib; }) {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "libexec"
      ];
      elfKinds = [ "runtime" ];
    })
    ((import ./ordinary/check-paths.nix { inherit lib; }) {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [
        "bin"
        "libexec"
      ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = final.features;
  meta = {
    description = "GNU archive utility";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
  upstreamPlan = artifact: [
    {
      name = "gnutar.restore-build-tree";
      tools = [ baseTools.python ];
      run = ''
        ${baseTools.python}/bin/python3 -B ${../utilities-restore.py} ${artifact}/nix-support/gnutar-build-tree "$TVP_SOURCE_ROOT"
        printf '%s\n' ${artifact} > "$TVP_SOURCE_ROOT/production-artifact"
      '';
    }

    {
      name = "gnutar.upstream-frontends";
      tools = [
        final.python
        final.perl
      ];
      run = ''
        cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        ${final.python}/bin/python3 -B ${./ordinary/upstream-source.py} ${final.bash}/bin/bash ${final.perl}/bin/perl '["tests"]'
      '';
    }
  ];
  plan =
    let
      parts = steps.partition final.originalPlan;
      production = builtins.filter (step: !(builtins.elem step.name [ "gnutar.check" ])) parts.first;
    in
    production
    ++ [
      {
        name = "gnutar.save-build-tree";
        tools = [
          baseTools.python
          final.coreutils
        ];
        run = ''
          ${baseTools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/nix-support/gnutar-build-tree"
        '';
      }
    ]
    ++ (lib.optional parts.split (steps.split "gnutar.finalize"))
    ++ [
      (builtins.head parts.second)
      {
        name = "gnutar.drop-build-tree";
        tools = [ final.coreutils ];
        run = ''${final.coreutils}/bin/rm -rf -- "$out/nix-support/gnutar-build-tree"'';
      }
    ]
    ++ builtins.tail parts.second;

}
