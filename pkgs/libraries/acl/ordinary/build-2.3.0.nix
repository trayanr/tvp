# Independent ACL 2.3.0/2.3.1, with measured GCC13 and unchanged hardening.
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
    "lib"
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
  tools = { inherit gnumake gnutar gzip python perl binutils patchelf sed grep gawk diffutils findutils; };
  libraries = { inherit attr; };
  dependencyProviders = final.tools // final.libraries;
  environment = {
    tools = [
      final.tools.gnumake
      final.tools.sed
      final.tools.grep
      final.tools.gawk
      final.tools.diffutils
      final.tools.findutils
    ];
    # Upstream links -lattr and the resulting DSO retains DT_NEEDED libattr.
    # Retain the old factory's propagated Attr development dependency.
    libraries = [ final.libraries.attr ];
  };
  runtime.libraries = [ final.libraries.attr ];
  artifactPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit (final.tools) gzip findutils;
      tar = final.tools.gnutar;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "acl.prepare";
      inherit (final.tools) python;
      bash = final.bash;
      base = final.base;
    })
    (steps.shebangs {
      name = "acl.source-shells";
      inherit (final.tools) python;
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
    (command "acl.build" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "acl.install" ''
      ${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
  ];
  inherit doCheck;
  upstreamPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit (final.tools) gzip findutils;
      tar = final.tools.gnutar;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "acl.prepare";
      inherit (final.tools) python;
      bash = final.bash;
      base = final.base;
    })
    (steps.shebangs {
      name = "acl.test-perl";
      inherit (final.tools) python;
      paths = [
        "test/run"
        "test/sort-getfacl-output"
      ];
      names = [ "perl" ];
      interpreter = "${final.tools.perl}/bin/perl";
    })
    (steps.shebangs {
      name = "acl.test-shells";
      inherit (final.tools) python;
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
      inherit (final.tools) python;
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
    (command "acl.build" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
  ];
  upstreamCheck = (
    (command "acl.check" ''
      "$CC" ${../../../../lib/tests/filesystem-capabilities.c} -o .tvp-filesystem-probe
      # Upstream preloads its glibc user/group lookup DSO into every command.
      # Retained Grep uses musl and performs no user/group lookup. Keep that
      # explicit command outside the interposer; tested ACL programs keep it.
      mkdir -p "$PWD/.tvp-check-tools"
      printf '%s\n' '#!${final.bash}/bin/bash' 'unset LD_PRELOAD' \
        'exec ${final.tools.grep}/bin/grep "$@"' > .tvp-check-tools/grep
      chmod +x .tvp-check-tools/grep
      export PATH="$PWD/.tvp-check-tools:$PATH"
      status=0
      ${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" check \
        TEST_LOG_COMPILER="${final.tools.python}/bin/python3 -B ${../../../../lib/tests/ordinary-test-runner.py} acl23 $PWD/.tvp-filesystem-probe $PWD/test/runwrapper" \
        || status=$?
      cat test-suite.log
      exit "$status"
    '')
    // {
      enabled = final.doCheck;
      tools = environment.tools ++ [
        final.libraries.attr
        final.tools.perl
        final.tools.python
      ];
    }
  );
  plan = steps.sequence (
    final.artifactPlan
    ++ [
      (steps.split "acl.finalize")
      (outputs.copyArtifacts { coreutils = final.coreutils; })
      (outputs.relocateText {
        inherit (final.tools) python;
        paths = [
          "lib/pkgconfig"
          "lib/libacl.la"
        ];
      })
      {
        name = "output.manuals";
        tools = [
          final.tools.gzip
          final.tools.findutils
        ];
        run = ''
          while IFS= read -r -d $'\0' manual; do
            ${final.tools.gzip}/bin/gzip -n -9 "$manual"
          done < <(find "$out/share/man" -type f ! -name '*.gz' -print0)
          while IFS= read -r -d "" manual; do
            target=$(readlink "$manual")
            rm "$manual"
            ln -s "$target.gz" "$manual.gz"
          done < <(find "$out/share/man" -type l ! -name '*.gz' -print0)
        '';
      }
      (outputs.strip {
        inherit (final.tools) python binutils;
        paths = elfPaths;
      })
      (outputs.stripArchives {
        inherit (final.tools) python binutils;
        paths = [ "lib/libacl.a" ];
      })
      (outputs.libtool {
        inherit (final.tools) python;
        paths = [ "lib/libacl.la" ];
      })
      (outputs.rpaths {
        inherit (final.tools) python binutils patchelf;
        base = final.base;
        libraries = final.runtime.libraries;
        dlopenDirectories = final.runtime.dlopenDirectories or [ ];
        paths = elfPaths;
      })
      (outputs.development {
        inherit (final.tools) python;
        libraries = [ final.libraries.attr ];
      })
      (outputs.checkSymlinks {
        inherit (final.tools) python;
        paths = [
          "lib/libacl.so"
          "lib/libacl.so.1"
        ];
      })
      (outputs.checkPaths {
        inherit (final.tools) python binutils patchelf;
        paths = elfPaths;
      })
    ]
  );
  tvp.features = {
    shared = true;
    static = true;
  };
  meta = {
    description = "POSIX access control list utilities and library";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.unix;
  };
}
