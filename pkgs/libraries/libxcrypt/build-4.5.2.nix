# Selected native release; older releases keep their original construction.
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
  perl,
  python,
  binutils,
  patchelf,
  gzip,
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
  elfPaths = [ "lib/libcrypt.so.1.1.0" ];
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
  pname = "libxcrypt";
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
      perl
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      inherit src xz;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      name = "libxcrypt.prepare";
      inherit bash python;
      base = final.base;
    })
    (command "libxcrypt.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash
      ./configure --prefix="$out" --enable-shared --enable-static
    '')
    (command "libxcrypt.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (
      (command "libxcrypt.check" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" check'')
      // {
        enabled = doCheck;
      }
    )
    (command "libxcrypt.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    {
      name = "output.manuals";
      tools = [ gzip ];
      run = ''find "$out/share/man" -type f -exec ${gzip}/bin/gzip -n -9 '{}' +'';
    }
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib/libcrypt.a" ];
    })
    (outputs.libtool {
      inherit python;
      paths = [ "lib/libcrypt.la" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = elfPaths;
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libcrypt.so"
        "lib/libcrypt.so.1"
        "lib/libxcrypt.so"
        "lib/libowcrypt.so"
        "lib/libowcrypt.so.1"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = {
    shared = true;
    static = true;
  };
  meta = {
    description = "Extended crypt library";
    homepage = "https://github.com/besser82/libxcrypt/";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
  };
}
