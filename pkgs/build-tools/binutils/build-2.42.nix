# Serves 2.42 onwards. The first base-ownership target is native x86_64 Linux.
{
  lib,
  stdenv,
  fetchurl,
  zlib,
  zstd,
  perl,
  pkg-config,
  bison,
  texinfo,
  version,
  sha256,
  gprofng ? true,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "binutils";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/binutils/binutils-${version}.tar.xz";
    inherit sha256;
  };
  nativeBuildInputs = [
    perl
    pkg-config
    bison
    texinfo
  ];
  buildInputs = [
    zlib
    zstd
  ];
  enableParallelBuilding = true;
  # Upstream recommends an out-of-tree build; the source tree stays untouched.
  preConfigure = ''
    # TVP's pkg-config does not yet carry a dependency-search setup hook.
    export PKG_CONFIG_PATH="${lib.getDev zstd}/lib/pkgconfig:${lib.getDev zlib}/lib/pkgconfig"
    mkdir -p ../build
    cd ../build
    configureScript="$NIX_BUILD_TOP/$sourceRoot/configure"
  '';
  configureFlags = [
    "--with-system-zlib"
    "--with-zstd"
    "--enable-plugins"
    "--enable-deterministic-archives"
    # Library locations belong to the caller's compiler/linker wrapper.
    "--with-lib-path=:"
  ] ++ lib.optional (!gprofng) "--disable-gprofng";
  meta = {
    description = "GNU assembler, linker and binary inspection tools (unwrapped)";
    homepage = "https://www.gnu.org/software/binutils/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    # Keep cc-wrapper's frontends first when both are installed in a shell.
    priority = 10;
  };
  passthru = {
    tvp.deps = {
      inherit
        zlib
        zstd
        perl
        pkg-config
        bison
        texinfo
        ;
    };
    tvp.cc = stdenv.cc;
    tvp.features.gprofng = gprofng;
    tests = mkTests finalAttrs.finalPackage;
  };
})
