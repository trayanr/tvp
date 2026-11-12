# Ordinary native 1.26 only: preserve shared database/compat libraries and all CLI utilities; no Readline/NLS library was declared by the retained recipe.
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
      name = "gdbm.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "gdbm";
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
    (steps.prepareAutotools {
      name = "gdbm.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
      cwd = "source";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --enable-shared --disable-static --enable-libgdbm-compat
    '')
    (command "build" make)
    (command "install" ''
      ${make} install
      mkdir -p "$out/include/gdbm"
      ln -s ../dbm.h ../gdbm.h ../ndbm.h "$out/include/gdbm/"
    '')
    (command "receipt" ''
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
  ];
  inherit doCheck;
  upstreamPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "gdbm.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
      cwd = "source";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --enable-shared --disable-static --enable-libgdbm-compat
    '')
    (command "build" make)
  ];
  upstreamCheck = ((command "check" ''${make} check'') // { enabled = final.doCheck; });
  plan = steps.sequence (
    final.artifactPlan
    ++ [
      (steps.split "gdbm.finalize")
      (outputs.copyArtifacts { coreutils = final.coreutils; })
      (outputs.relocateText {
        inherit python;
        paths = [
          "lib/pkgconfig"
          "lib/libgdbm.la"
          "lib/libgdbm_compat.la"
        ];
      })
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
    compatLib = true;
    shared = true;
    static = false;
  };
  meta = {
    description = "GNU dbm key/value database library";
    homepage = "https://www.gnu.org/software/gdbm/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "gdbmtool";
  };
}
