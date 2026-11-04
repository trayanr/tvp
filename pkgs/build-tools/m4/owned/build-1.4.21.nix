# 1.4.21 only. Configure embeds its final installation prefix; keep one stage.
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
  pname = "m4";
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
    shell = bash;
  };
  plan = steps.sequence [
    (steps.unpack {
      inherit src gzip;
      tar = gnutar;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "m4.prepare";
      inherit bash python;
      base = final.base;
    })
    (steps.shebangs {
      name = "m4.check-shells";
      inherit python;
      paths = [
        "checks"
        "tests"
        "build-aux"
      ];
      names = [ "sh" ];
      interpreter = "${bash}/bin/bash";
    })
    (command "m4.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash
      ./configure --prefix="$out" --with-syscmd-shell=${final.runtime.shell}/bin/bash
    '')
    (command "m4.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash'')
    (
      (command "m4.check" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash check'')
      // {
        enabled = doCheck;
      }
    )
    (command "m4.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    {
      name = "output.manuals";
      tools = [ gzip ];
      run = ''
        ${gzip}/bin/gzip -n -9 "$out/share/man/man1/m4.1"
        rm -f "$out/share/info/dir"
      '';
    }
    (outputs.strip {
      inherit python binutils;
      paths = [ "bin/m4" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = [ "bin/m4" ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [ "bin/m4" ];
    })
  ];
  meta = {
    description = "GNU macro processor";
    homepage = "https://www.gnu.org/software/m4/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "m4";
  };
}
