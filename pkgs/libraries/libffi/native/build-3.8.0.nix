# Ordinary native 3.8.0 only: the selected ABI/closure implementation uses root public headers and a shared-only ordinary output.
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

  dejagnu,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "libffi.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "libffi";
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
      name = "libffi.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
      cwd = "source";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib" --disable-multi-os-directory --enable-shared --disable-static
    '')
    (command "build" make)
    (command "install" ''
      ${make} install
      # Preserve the ordinary x86_64 compatibility spelling after relocating to lib.
      ln -s lib "$out/lib64"
    '')
    (command "receipt" ''
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
  ];
  inherit doCheck;
  upstreamPlan = map (step: step // { tools = (step.tools or [ ]) ++ [ dejagnu ]; }) (steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "libffi.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
      cwd = "source";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib" --disable-multi-os-directory --enable-shared --disable-static
    '')
    (command "build" make)
  ]);
  upstreamCheck =
    ((command "check" ''${make} check'') // { enabled = final.doCheck; });
  plan = steps.sequence (final.artifactPlan ++ [
    (steps.split "libffi.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (outputs.relocateText {
      inherit python;
      paths = ["lib/pkgconfig" "lib/libffi.la"];
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
  ]);
  tvp.features = {
    headersInIncludedir = true;
    variadic = true;
    versionFunction = true;
    shared = true;
    static = false;
  };
  meta = {
    description = "Foreign function interface library";
    homepage = "https://sourceware.org/libffi/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
