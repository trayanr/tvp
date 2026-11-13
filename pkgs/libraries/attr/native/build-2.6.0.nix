# Native source-GNU catalogue route; retained bootstrap procedure stays independent.
# 2.6.0 only. Rebase compiled locale/configuration paths after the artifact split.
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
}@args:
final:
let
  inherit (final)
    base
    src
    version
    bash
    coreutils
    ;
  inherit (tvp.builder) steps outputs;
  elfPaths = [
    "bin"
    "lib/libattr.so.1.1.2600"
  ];
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
  pname = "attr";
  inherit (args)
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
    libraries = [ ];
  };
  runtime.libraries = [ ];
  artifactPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit gzip findutils;
      tar = gnutar;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "attr.prepare";
      inherit bash python;
      base = final.base;
    })
    (steps.shebangs {
      name = "attr.source-shells";
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
    (command "attr.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --enable-shared --enable-static
    '')
    (command "attr.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "attr.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
  ];
  inherit doCheck;
  upstreamPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit gzip findutils;
      tar = gnutar;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "attr.prepare";
      inherit bash python;
      base = final.base;
    })
    (steps.shebangs {
      name = "attr.test-perl";
      inherit python;
      paths = [
        "test/run"
        "test/sort-getfattr-output"
      ];
      names = [ "perl" ];
      interpreter = "${perl}/bin/perl";
    })
    (steps.shebangs {
      name = "attr.source-shells";
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
    (command "attr.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --enable-shared --enable-static
    '')
    (command "attr.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
  ];
  upstreamCheck = (
    (command "attr.check" ''
      "$CC" ${../../../../lib/tests/filesystem-capabilities.c} -o .tvp-filesystem-probe
      status=0
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" check \
        RUN_LOG_COMPILER="${python}/bin/python3 -B ${../../../../lib/tests/filesystem-test-runner.py} attr $PWD/.tvp-filesystem-probe $PWD/test/run" \
        || status=$?
      cat test-suite.log
      exit "$status"
    '')
    // {
      enabled = final.doCheck;
      tools = environment.tools ++ [
        perl
        python
      ];
    }
  );
  plan = steps.sequence (
    final.artifactPlan
    ++ [
      (steps.split "attr.finalize")
      (outputs.copyArtifacts { coreutils = final.coreutils; })
      {
        name = "attr.relocate";
        tools = [
          python
          binutils
          patchelf
        ];
        # Use the same prefix relocation as Attr 2.5.x. Fixed-width slash padding
        # keeps native/archive string positions while rebasing locale/config paths.
        run = ''${python}/bin/python3 -B ${../../ordinary-attr-crypt-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${patchelf}/bin/patchelf ${
          lib.escapeShellArg (
            builtins.toJSON {
              readelf = "${binutils}/bin/readelf";
              requiredDirectories = [
                "bin"
                "lib"
                "share/man"
                "nix-support"
              ];
              requiredFiles = [
                "bin/attr"
                "bin/getfattr"
                "bin/setfattr"
                "lib/libattr.a"
                "lib/libattr.la"
                "lib/libattr.so.1.1.2600"
                "lib/pkgconfig/libattr.pc"
              ];
              requiredRegular = [
                "lib/libattr.a"
                "lib/libattr.la"
                "nix-support/propagated-build-inputs"
              ];
              libtoolData = [ "lib/libattr.la" ];
              buildShell = "${bash}/bin/bash";
              shell = "${bash}/bin/bash";
              paths = [ ];
            }
          )
        }'';
      }
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
        paths = [ "lib/libattr.a" ];
      })
      (outputs.libtool {
        inherit python;
        paths = [ "lib/libattr.la" ];
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
          "lib/libattr.so"
          "lib/libattr.so.1"
        ];
      })
      (outputs.checkPaths {
        inherit python binutils patchelf;
        paths = elfPaths;
      })
    ]
  );
  tvp.features = {
    shared = true;
    static = true;
  };
  meta = {
    description = "Extended attribute utilities and library";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
  };
}
