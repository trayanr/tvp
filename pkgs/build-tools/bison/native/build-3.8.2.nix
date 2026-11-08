# Ordinary 3.8.2 onward: independent owned procedure with shipped generated
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
  m4,
  perl,
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
  pname = "bison";
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
      m4
      perl
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "bison.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    (command "bison.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" M4=${m4}/bin/m4 ${lib.escapeShellArgs configureFlags}
    '')
    (command "bison.build" make)
    (command "bison.install" ''
      ${make} install
      test -s "$out/share/bison/skeletons/yacc.c"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (outputs.shebangs {
      inherit python;
      paths = [ "bin/yacc" ];
      names = [ "sh" ];
      interpreter = "${final.bash}/bin/bash";
    })
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
    description = "GNU parser generator";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "bison";
  };
}
