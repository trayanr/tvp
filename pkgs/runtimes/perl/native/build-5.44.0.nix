# Ordinary native 5.44.0 only: full interpreter and installed core/XS/embedding interfaces; Config retains the selected compiler and Make paths.
# Earlier releases and source-bootstrap generations retain independent procedures.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  pkgConfig,
  gnumake,
  gnutar,
  gzip,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  python,
  binutils,
  patchelf,

  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "perl.${name}";
      cwd = "source";
      inherit run;
    };
  pythonCommand =
    name: run:
    (final.base.environment (final.environment // { tools = final.environment.tools ++ [ python ]; }))
    // {
      name = "perl.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "perl";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [
      pkgConfig
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
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.shebangs {
      name = "perl.prepare-shells";
      inherit python;
      paths = [
        "Configure"
        "hints"
      ];
      names = [ "sh" ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      # Configure publishes the operational command as "make" regardless of an
      # absolute input. Preserve that consumer contract through the declared
      # host tool, without retaining its path only in config_args.
      ${final.bash}/bin/bash ./Configure -des -Dprefix="$out" -Duseshrplib \
        '-Dlocincpth= ' '-Dloclibpth= ' -Dcc="$CC" -Dld="$CC" \
        -Dar="$AR" -Dnm="$NM" -Dranlib="$RANLIB" -Dmake=make \
        -Dsh=${final.bash}/bin/bash
    '')
    (command "build" make)
    (command "install" ''
      ${make} install
    '')
    (command "receipt" ''
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
  ];
  artifactName = "${final.pname}-${final.version}";
  finalizeHelper = ./../ordinary/elf-finalize.py;
  inherit doCheck;
  upstreamPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.shebangs {
      name = "perl.prepare-shells";
      inherit python;
      paths = [
        "Configure"
        "hints"
      ];
      names = [ "sh" ];
      interpreter = "${final.bash}/bin/bash";
    })
    (pythonCommand "test-diff" ''
      ${python}/bin/python3 -B - <<'PYTHON'
      from pathlib import Path
      p = Path('ext/Pod-Html/t/lib/Testing.pm')
      text = p.read_text()
      old = "my $diff = '/bin/diff';"
      assert text.count(old) == 1
      p.write_text(text.replace(old, "my $diff = '${diffutils}/bin/diff';"))
      PYTHON
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      # Configure publishes the operational command as "make" regardless of an
      # absolute input. Preserve that consumer contract through the declared
      # host tool, without retaining its path only in config_args.
      ${final.bash}/bin/bash ./Configure -des -Dprefix="$out" -Duseshrplib \
        '-Dlocincpth= ' '-Dloclibpth= ' -Dcc="$CC" -Dld="$CC" \
        -Dar="$AR" -Dnm="$NM" -Dranlib="$RANLIB" -Dmake=make \
        -Dsh=${final.bash}/bin/bash
    '')
    (command "build" make)
  ];
  upstreamCheck = (
    (command "check" ''TEST_JOBS="$NIX_BUILD_CORES" ${make} test_harness'')
    // {
      enabled = final.doCheck;
    }
  );
  plan = steps.sequence (
    final.artifactPlan
    ++ [
      (steps.split "perl.finalize")
      (outputs.copyArtifacts { coreutils = final.coreutils; })
      {
        name = "perl.relocate";
        tools = [
          python
          binutils
          patchelf
        ];
        run = ''${python}/bin/python3 -B ${final.finalizeHelper} ${
          lib.escapeShellArg (
            builtins.toJSON {
              readelf = "${binutils}/bin/readelf";
              patchelf = "${patchelf}/bin/patchelf";
              externalPwd = false;
            }
          )
        } "$out" "$TVP_ARTIFACT_ROOT"'';
      }
      (outputs.shebangs {
        inherit python;
        paths = [ "bin" ];
        names = [
          "perl"
          "perl5.44.0"
        ];
        selfInterpreter = "bin/perl";
      })
      (
        (outputs.shebangs {
          inherit python;
          paths = [
            "bin"
            "lib"
          ];
          names = [
            "sh"
            "bash"
          ];
          interpreter = "${final.bash}/bin/bash";
        })
        // {
          name = "output.shell-shebangs";
        }
      )
      (outputs.strip {
        inherit python binutils;
        paths = [
          "bin"
          "lib"
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
          "lib"
        ];
        elfKinds = [ "runtime" ];
      })
      (outputs.development {
        inherit python;
        libraries = [ ];
      })
      (outputs.checkPaths {
        inherit python binutils patchelf;
        paths = [
          "bin"
          "lib"
        ];
        elfKinds = [ "runtime" ];
      })
    ]
  );
  tvp.features = {
    globImportable = false;
    shared = true;
    xs = true;
  };
  meta = {
    description = "Highly capable, feature-rich programming language";
    homepage = "https://www.perl.org/";
    license = lib.licenses.artistic1;
    platforms = [ "x86_64-linux" ];
    mainProgram = "perl";
  };
}
