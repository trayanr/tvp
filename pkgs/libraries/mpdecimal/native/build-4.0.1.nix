# Ordinary native 4.0.1 only: the corrected shared-link procedure supports both C/C++; 4.0.0 retains its measured old-only compiler-driver workaround.
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
      name = "mpdecimal.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "mpdecimal";
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
      name = "mpdecimal.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
      cwd = "source";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --enable-shared --disable-static --enable-cxx
    '')
    (command "build" make)
    (command "install" ''${make} install'')
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
      name = "mpdecimal.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
      cwd = "source";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --enable-shared --disable-static --enable-cxx
    '')
    (command "build" make)
  ];
  upstreamCheck = ((command "check" ''${make} check_local'') // { enabled = final.doCheck; });
  plan = steps.sequence (
    final.artifactPlan
    ++ [
      (steps.split "mpdecimal.finalize")
      (outputs.copyArtifacts { coreutils = final.coreutils; })
      (outputs.relocateText {
        inherit python;
        paths = [ "lib/pkgconfig" ];
      })
      (outputs.shebangs {
        inherit python;
        paths = [ "lib" ];
        names = [
          "sh"
          "bash"
        ];
        interpreter = "${final.bash}/bin/bash";
      })
      (outputs.strip {
        inherit python binutils;
        paths = [ "lib" ];
        elfKinds = [ "runtime" ];
      })
      (outputs.rpaths {
        inherit python binutils patchelf;
        base = final.base;
        libraries = final.runtime.libraries;
        dlopenDirectories = final.runtime.dlopenDirectories or [ ];
        paths = [ "lib" ];
        elfKinds = [ "runtime" ];
      })
      (outputs.development {
        inherit python;
        libraries = [ ];
      })
      (outputs.checkPaths {
        inherit python binutils patchelf;
        paths = [ "lib" ];
        elfKinds = [ "runtime" ];
      })
    ]
  );
  tvp.features = {
    shared = true;
    static = false;
    cxx = true;
  };
  meta = {
    description = "Correctly rounded arbitrary-precision decimal arithmetic libraries";
    homepage = "https://www.bytereef.org/mpdecimal/";
    license = lib.licenses.bsd2;
    platforms = [ "x86_64-linux" ];
  };
}
