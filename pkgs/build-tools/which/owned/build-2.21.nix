# 2.21 only. Configure embeds its final installation prefix; keep one stage.
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
  pname = "which";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [ gnumake ];
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
  };
  plan = steps.sequence [
    (steps.unpack {
      inherit src gzip;
      tar = gnutar;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "which.prepare";
      inherit bash python;
      base = final.base;
    })

    (command "which.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash
      ./configure --prefix="$out"
    '')
    (command "which.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash'')
    (
      (command "which.check" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash check'')
      // {
        enabled = doCheck;
      }
    )
    (command "which.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    {
      name = "output.manuals";
      tools = [ gzip ];
      run = ''
        ${gzip}/bin/gzip -n -9 "$out/share/man/man1/which.1"
        rm -f "$out/share/info/dir"
      '';
    }
    (outputs.strip {
      inherit python binutils;
      paths = [ "bin/which" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = [ "bin/which" ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
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
