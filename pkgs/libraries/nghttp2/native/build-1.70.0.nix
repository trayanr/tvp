# Native ordinary 1.70.0: lib-only Autotools, raw upstream make check,
# shared/static/pkg-config install; the former stdenv procedure stays frozen.
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
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  pkg-config,
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
      name = "nghttp2.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash'';
in
{
  pname = "nghttp2";
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
      pkg-config
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz findutils;
      tar = gnutar;
    })
    (steps.prepareAutotools {
      inherit python base bash;
      name = "nghttp2.prepare";
    })
    (command "configure" ''
      export CONFIG_SHELL=${bash}/bin/bash SHELL=${bash}/bin/bash
      ./configure --prefix="$out" --enable-lib-only
    '')
    (command "build" make)
    ((command "check" "${make} check") // { enabled = doCheck; })
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "nghttp2.finalize")
    (outputs.copyArtifacts { inherit coreutils; })
    (outputs.relocateText {
      inherit python;
      paths = [
        "lib/pkgconfig/libnghttp2.pc"
        "lib/libnghttp2.la"
      ];
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
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libnghttp2.so"
        "lib/libnghttp2.so.14"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [ "lib" ];
    })
  ];
  tvp.features = {
    inherit doCheck;
    libOnly = true;
    shared = true;
    static = true;
    pkgConfig = true;
  };
  meta = {
    description = "HTTP/2 C library with HPACK compression";
    homepage = "https://nghttp2.org/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
