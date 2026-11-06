# Selected source-native release; canonical family construction is unchanged.
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
  python,
  binutils,
  patchelf,
  gmp,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "isl.${name}";
      cwd = "source";
      run = run;
    };
in
{
  pname = "isl";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [ gnumake ];
    libraries = [ gmp ];
  };
  runtime.libraries = [ gmp ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      name = "isl.prepare";
      inherit bash python;
      base = final.base;
    })

    (command "configure" ''
      export CONFIG_SHELL=${bash}/bin/bash SHELL=${bash}/bin/bash
      ./configure --prefix="$out" --with-gmp=system --with-gmp-prefix=${gmp} --enable-shared --enable-static
    '')
    (command "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash'')
    (command "check" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash check'')
    (command "install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (outputs.libtool {
      inherit python;
      paths = [ "lib/libisl.la" ];
    })
    (outputs.strip {
      inherit python binutils;
      paths = [ "lib" ];
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = [ "lib" ];
    })
    (outputs.development {
      inherit python;
      libraries = [ gmp ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [ "lib" ];
    })
  ];
  tvp.features = {
    shared = true;
    static = true;
    cxx = true;
  };
  meta.platforms = [ "x86_64-linux" ];
}
