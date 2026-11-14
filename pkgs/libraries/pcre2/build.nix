# PCRE2 10.44–10.49: one complete all-widths/Unicode/JIT production procedure.
{
  tvp,
  lib,
  base,
  src,
  version,
  pkgConfig,
  doCheck ? true,
  static ? false,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  checkpoint = "nix-support/pcre2-build-tree";
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "pcre2.${name}";
      cwd = "source";
      inherit run;
    };
in
{
  pname = "pcre2";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    pkgConfig
    doCheck
    static
    ;
  inherit (tools) bash coreutils;
  dependencyProviders.pkgConfig = final.pkgConfig;
  buildFeatures = {
    jit = true;
    unicode = true;
    shared = true;
    static = final.static;
  };
  installedInterface.widths = [
    8
    16
    32
  ];
  environment = {
    tools = [
      final.pkgConfig
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
    shell = tools.bash;
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "bzip2";
    })
    (steps.prepareAutotools {
      name = "pcre2.prepare";
    })
    (steps.shebangs {
      name = "pcre2.source-shells";
      paths = [
        "compile"
        "config.guess"
        "config.sub"
        "install-sh"
        "missing"
        "depcomp"
        "ar-lib"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      ./configure --prefix="$out" --enable-pcre2-16 --enable-pcre2-32 \
        ${lib.enableFeature final.buildFeatures.jit "jit"} \
        ${lib.enableFeature final.buildFeatures.unicode "unicode"} \
        ${lib.enableFeature final.buildFeatures.shared "shared"} \
        ${lib.enableFeature final.buildFeatures.static "static"}
    '')
    (command "build" ''
      # Installed libraries/CLIs only; noinst test programs belong to U.
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash \
        libpcre2-8.la libpcre2-16.la libpcre2-32.la libpcre2-posix.la pcre2grep pcre2test
    '')
    (command "install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash install-exec-am install-data-am
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (command "save-build-tree" ''
      ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
    '')
  ];
  upstreamPreparation = [
    {
      name = "pcre2.callout-echo";
      tools = [
        tools.python
        tools.coreutils
      ];
      run = ''${tools.python}/bin/python3 -B ${./tests/prepare.py} ${tools.coreutils}/bin/echo'';
    }
    (steps.shebangs {
      name = "pcre2.test-shells";
      paths = [
        "RunTest"
        "RunGrepTest"
        "test-driver"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${tools.bash}/bin/bash";
    })
  ];
  upstreamPlan =
    artifact:
    [
      {
        name = "pcre2.restore-build-tree";
        tools = [ tools.python ];
        run = ''${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
      }
    ]
    ++ map (
      step:
      step
      // {
        cwd = ".";
        run = ''
          cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
          ${step.run}
        '';
      }
    ) final.upstreamPreparation;
  upstreamCheck =
    (command "check" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash check'')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "pcre2.finalize")
    (outputs.copyArtifacts { preserveHardlinks = false; })
    {
      name = "pcre2.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "pcre2.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../../build-tools/owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" '{}' ${../../../lib/installed-tree.py}'';
    }
    {
      name = "pcre2.self-rpaths";
      tools = [
        tools.python
        tools.patchelf
      ];
      run = ''
        ${tools.python}/bin/python3 -B - "$out" ${tools.patchelf}/bin/patchelf <<'PYTHON'
        from pathlib import Path
        import subprocess, sys
        root = Path(sys.argv[1])
        for directory in ['bin', 'lib']:
            for p in sorted((root/directory).iterdir()):
                if p.is_symlink() or not p.is_file(): continue
                with p.open('rb') as f: magic=f.read(4)
                if magic == b'\x7fELF':
                    subprocess.run([sys.argv[2], '--add-rpath', str(root/'lib'), str(p)], check=True)
        PYTHON
      '';
    }
    (outputs.shebangs {
      paths = [
        "bin"
        "lib"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (outputs.strip {
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.stripArchives {
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.development {
      libraries = [ ];
    })
    (outputs.checkPaths {
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  tvp.features = final.buildFeatures;
  meta = {
    description = "Perl-compatible regular expressions library";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}
