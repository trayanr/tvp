# GNU Tar 1.32–1.34: complete ordinary procedure. All three release archives
# have the same generated Autotools/gnulib layout; PAX fixture semantics vary.
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
  inherit
    base
    src
    version
    bash
    ;
  inherit
    coreutils
    gnumake
    gnutar
    xz
    gzip
    python
    perl
    binutils
    patchelf
    sed
    grep
    gawk
    diffutils
    findutils
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
    bash = final.bash;
    coreutils = final.coreutils;
    gnumake = final.gnumake;
    gnutar = final.gnutar;
    xz = final.xz;
    gzip = final.gzip;
    python = final.python;
    perl = final.perl;
    binutils = final.binutils;
    patchelf = final.patchelf;
    sed = final.sed;
    grep = final.grep;
    gawk = final.gawk;
    diffutils = final.diffutils;
    findutils = final.findutils;
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
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      xz = final.xz;
      findutils = final.findutils;
      tar = final.gnutar;
    })
    (command "gnutar.prepare" ''
      ${final.python}/bin/python3 -B ${./source.py} ${final.bash}/bin/bash ${final.perl}/bin/perl '["build-aux","tests","scripts"]'
    '')
    (command "gnutar.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
      ${lib.optionalString final.features.nls "grep '^#define ENABLE_NLS 1' config.h"}
      ${lib.optionalString final.features.acls "grep -F '#define HAVE_POSIX_ACLS /**/' config.h"}
      ${lib.optionalString final.features.xattrs "grep -F '#define HAVE_XATTRS /**/' config.h"}
    '')
    (command "gnutar.build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
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
      ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
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
      run = ''${final.python}/bin/python3 -B ${./output.py} "$out" "$TVP_ARTIFACT_ROOT" ${final.patchelf}/bin/patchelf ${
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
    ((import ./rpaths.nix { inherit lib; }) {
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
    ((import ./check-paths.nix { inherit lib; }) {
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
}
