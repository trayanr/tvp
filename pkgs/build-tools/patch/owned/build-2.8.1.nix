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
  xz,
  gzip,
  python,
  binutils,
  patchelf,
  patch,
  patches ? [ ],
  doCheck ? true,
  configureFlags ? [ ],
  stripFlags ? [
    "-S"
    "-p"
  ],
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
  pname = "patch";
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
  runtime.libraries = [ ];
  # A single stage retains the configured installation paths without relocation.
  plan = steps.sequence [
    (steps.unpack {
      inherit src xz;
      tar = gnutar;
    })
    (command "patch.sources" ''
      for file in ${lib.escapeShellArgs (map (p: "${p}") patches)}; do
        ${patch}/bin/patch -p1 < "$file"
      done
    '')
    (command "patch.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash
      ${bash}/bin/bash ./configure --prefix="$out" --disable-dependency-tracking \
        ${lib.escapeShellArgs configureFlags}
    '')
    (command "patch.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash'')
    (
      (command "patch.check" ''
        status=0
        ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash check || status=$?
        if (( status )); then cat tests/test-suite.log >&2 || :; fi
        exit "$status"
      '')
      // {
        enabled = doCheck;
      }
    )
    (command "patch.install" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash install'')
    {
      name = "output.manuals";
      tools = [ gzip ];
      run = ''
        ${gzip}/bin/gzip -n -9 "$out/share/man/man1/patch.1"
      '';
    }
    (outputs.strip {
      inherit python binutils;
      paths = [ "bin/patch" ];
      flags = stripFlags;
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = [ "bin/patch" ];
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [ "bin/patch" ];
    })
  ];
  meta = {
    description = "GNU patch application utility";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "patch";
  };
}
