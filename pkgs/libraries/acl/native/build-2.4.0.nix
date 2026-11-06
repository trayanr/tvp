# Native source-GNU catalogue route; retained bootstrap procedure stays independent.
# 2.4.0 only. Compiled locale/configuration paths retain the configured prefix.
{
  tvp,
  lib,
  base,
  src,
  version,
  attr,
  bash,
  coreutils,
  gnumake,
  gnutar,
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
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
  elfPaths = [
    "bin"
    "lib/libacl.so.1.2.2400"
  ];
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
  pname = "acl";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
    ];
    # Build-only error_context.h helpers; public ACL headers forward-declare
    # the optional struct, and libacl no longer links libattr.
    libraries = [ attr ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      inherit src gzip findutils;
      tar = gnutar;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "acl.prepare";
      inherit bash python;
      base = final.base;
    })
    (steps.shebangs {
      name = "acl.test-perl";
      inherit python;
      paths = [
        "test/run"
        "test/sort-getfacl-output"
      ];
      names = [ "perl" ];
      interpreter = "${perl}/bin/perl";
    })
    (steps.shebangs {
      name = "acl.test-shells";
      inherit python;
      paths = [
        "test/runwrapper"
        "test/make-tree"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${bash}/bin/bash";
    })
    (steps.shebangs {
      name = "acl.source-shells";
      inherit python;
      paths = [
        "configure"
        "build-aux"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${bash}/bin/bash";
    })
    (command "acl.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --enable-shared --enable-static
    '')
    (command "acl.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (
      (command "acl.check" ''
        "$CC" ${../../../../lib/tests/filesystem-capabilities.c} -o .tvp-filesystem-probe
        status=0
        ${gnumake}/bin/make -j"$NIX_BUILD_CORES" check \
          RUN_LOG_COMPILER="${python}/bin/python3 -B ${../../../../lib/tests/filesystem-test-runner.py} acl $PWD/.tvp-filesystem-probe $PWD/test/runwrapper" \
          || status=$?
        cat test-suite.log
        exit "$status"
      '')
      // {
        enabled = doCheck;
        tools = environment.tools ++ [
          perl
          python
        ];
      }
    )
    (command "acl.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    {
      name = "output.manuals";
      tools = [
        gzip
        findutils
      ];
      run = ''
        while IFS= read -r -d $'\0' manual; do
          ${gzip}/bin/gzip -n -9 "$manual"
        done < <(find "$out/share/man" -type f ! -name '*.gz' -print0)
        while IFS= read -r -d "" manual; do
          target=$(readlink "$manual")
          rm "$manual"
          ln -s "$target.gz" "$manual.gz"
        done < <(find "$out/share/man" -type l ! -name '*.gz' -print0)
      '';
    }
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib/libacl.a" ];
    })
    (outputs.libtool {
      inherit python;
      paths = [ "lib/libacl.la" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = elfPaths;
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libacl.so"
        "lib/libacl.so.1"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = {
    shared = true;
    static = true;
  };
  meta = {
    description = "Access control list utilities and library";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
  };
}
