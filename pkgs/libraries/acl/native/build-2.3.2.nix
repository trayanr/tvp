# Native 2.3.2 compatibility line: Tar requires the pre-2.4 public API.
# Serves 2.3.2 only; older releases retain their measured GCC13 procedures.
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
    "lib/libacl.so.1.1.2302"
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
    # Upstream links -lattr and the resulting DSO retains DT_NEEDED libattr.
    # Public headers forward-declare error_context; isolated public/static
    # consumers do not require Attr headers or libraries.
    libraries = [ attr ];
  };
  runtime.libraries = [ attr ];
  artifactPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit gzip findutils;
      tar = gnutar;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "acl.prepare";
      inherit python;
      bash = final.bash;
      base = final.base;
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
      interpreter = "${final.bash}/bin/bash";
    })
    (command "acl.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --enable-shared --enable-static
    '')
    (command "acl.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "acl.install" ''
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
      name = "acl.prepare";
      inherit python;
      bash = final.bash;
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
      interpreter = "${final.bash}/bin/bash";
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
      interpreter = "${final.bash}/bin/bash";
    })
    (command "acl.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --enable-shared --enable-static
    '')
    (command "acl.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
  ];
  upstreamCheck = (
    (command "acl.check" ''
      "$CC" ${../../../../lib/tests/filesystem-capabilities.c} -o .tvp-filesystem-probe
      # Upstream preloads its glibc user/group lookup DSO into every command.
      # Retained Grep uses musl and performs no user/group lookup. Keep that
      # explicit command outside the interposer; tested ACL programs keep it.
      mkdir -p "$PWD/.tvp-check-tools"
      printf '%s\n' '#!${final.bash}/bin/bash' 'unset LD_PRELOAD' \
        'exec ${grep}/bin/grep "$@"' > .tvp-check-tools/grep
      chmod +x .tvp-check-tools/grep
      export PATH="$PWD/.tvp-check-tools:$PATH"
      status=0
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" check \
        TEST_LOG_COMPILER="${python}/bin/python3 -B ${../../../../lib/tests/ordinary-test-runner.py} acl23 $PWD/.tvp-filesystem-probe $PWD/test/runwrapper" \
        || status=$?
      cat test-suite.log
      exit "$status"
    '')
    // {
      enabled = final.doCheck;
      tools = environment.tools ++ [
        attr
        perl
        python
      ];
    }
  );
  plan = steps.sequence (
    final.artifactPlan
    ++ [
      (steps.split "acl.finalize")
      (outputs.copyArtifacts { coreutils = final.coreutils; })
      (import ./relocate-prefix.nix {
        inherit
          lib
          python
          binutils
          patchelf
          ;
        bash = final.bash;
      })
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
    ]
  );
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
