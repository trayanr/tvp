# Ordinary 3.3 onward: independent owned procedure with shipped generated
# sources and configure files. Historical/bootstrap procedures remain separate.
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
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  python,
  binutils,
  patchelf,
  libstdcxx,
  configureFlags ? [ ],
}:
let
  inherit (tvp.builder) steps outputs;
in
final:
let
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
      cwd = "source";
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  elfPaths = [ "bin" ];
in
{
  pname = "gperf";
  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
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
    libraries = [ ];
  };
  runtime.libraries = [ libstdcxx ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "gperf.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    (command "gperf.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out"  ${lib.escapeShellArgs configureFlags}
    '')
    (command "gperf.build" make)
    (command "gperf.install" ''
      ${make} install
      :
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "gperf.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "gperf.relocate";
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

    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })

    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })

    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  meta = {
    homepage = "https://www.gnu.org/software/gperf/";
    description = "GNU perfect hash function generator";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "gperf";
  };
}
