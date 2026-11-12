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
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  doCheck ? true,
  configureFlags ? [ ],
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
  pname = "which";
  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    bash
    coreutils
    python
    gnumake
    gnutar
    gzip
    gawk
    diffutils
    findutils
    binutils
    patchelf
    sed
    grep
    doCheck
    configureFlags
    ;
  environment = {
    tools = [
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
    ];
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
  };
  upstreamCheck = {
    enabled = final.doCheck;
    before = "which.install";
    command = (
      (command "which.check" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash check'')
      // {
        enabled = final.doCheck;
      }
    );
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      gzip = final.gzip;
      tar = final.gnutar;
      findutils = final.findutils;
      compression = "gzip";
    })
    (steps.shebangs {
      name = "which.prepare";
      python = final.python;
      paths = [ "configure" ];
      names = [ "sh" ];
      interpreter = "${final.bash}/bin/bash";
    })

    (command "which.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "which.build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (command "which.install" ''
      ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "which.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "which.relocate";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            text = [ ];
            slots = [ ];
            fixed = [ ];
          }
        )
      } ${../../../../lib/installed-tree.py}'';
    }
    {
      name = "output.manuals";
      tools = [ final.gzip ];
      run = ''
        ${final.gzip}/bin/gzip -n -9 "$out/share/man/man1/which.1"
        rm -f "$out/share/info/dir"
      '';
    }
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = [ "bin/which" ];
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin/which" ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [ "bin/which" ];
    })
  ];
  meta = {
    description = "GNU command path lookup";
    homepage = "https://www.gnu.org/software/which/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "which";
  };
}
