# Bison 3.6.4–3.7.6 need GNU17 for bundled gnulib attributes; generated examples need header ordering.
# Complete ordinary procedure; latest and frozen construction remain independently selected.
{
  testAutoconf,
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
  patch,
  patches ? [ ],
  postPatch ? "",
  cStandard ? null,
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
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  elfPaths = [ "bin" ];
in
{
  pname = "bison";
  inherit testAutoconf;
  upstreamPrerequisites = [
    "examples/c/reccalc/parse.c"
    "examples/c/lexcalc/parse.c"
  ];
  skeletonDirectory = "share/bison/skeletons";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  inherit
    gnumake
    gnutar
    gzip
    findutils
    sed
    grep
    gawk
    diffutils
    python
    binutils
    patchelf
    m4
    perl
    configureFlags
    ;
  inherit
    patch
    patches
    postPatch
    cStandard
    ;
  dependencyProviders = {
    testAutoconf = final.testAutoconf;
    bash = final.bash;
    coreutils = final.coreutils;
    gnumake = final.gnumake;
    gnutar = final.gnutar;
    gzip = final.gzip;
    findutils = final.findutils;
    sed = final.sed;
    grep = final.grep;
    gawk = final.gawk;
    diffutils = final.diffutils;
    python = final.python;
    binutils = final.binutils;
    patchelf = final.patchelf;
    m4 = final.m4;
    perl = final.perl;
    patch = final.patch;
  };
  environment = {
    tools = [
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.m4
      final.perl
    ];
    libraries = [ ];
    overrides.flags.NIX_CFLAGS_COMPILE = lib.optional (
      final.cStandard != null
    ) "-std=${final.cStandard}";
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      findutils = final.findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "bison.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    (command "bison.patches" ''
      for patch in ${lib.escapeShellArgs (map (p: "${p}") final.patches)}; do
        ${final.patch}/bin/patch -p1 < "$patch"
      done
      ${final.postPatch}
    '')
    (command "bison.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" M4=${final.m4}/bin/m4 ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "bison.build" make)
    (command "bison.install" ''
      ${make} install
      test -s "$out/${final.skeletonDirectory}/yacc.c"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "bison.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (outputs.shebangs {
      python = final.python;
      paths = [ "bin/yacc" ];
      names = [ "sh" ];
      interpreter = "${final.bash}/bin/bash";
    })
    {
      name = "bison.relocate";
      tools = [ final.python ];
      run = ''
        ${final.python}/bin/python3 -B ${./relocate.py} "$out" "$TVP_ARTIFACT_ROOT" "${final.patchelf}/bin/patchelf"
      '';
    }
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = elfPaths;
    })

    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development {
      python = final.python;
      libraries = [ ];
    })

    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = elfPaths;
    })
  ];
  meta = {
    homepage = "https://www.gnu.org/software/bison/";
    description = "GNU parser generator";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "bison";
  };
}
