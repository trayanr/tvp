# Serves 8.6.0 onwards.
{
  lib,
  stdenv,
  fetchurl,

  # Not optional: configure probes for zlib.h and silently falls back to the
  # copy bundled in compat/zlib, so a missing dependency builds clean and links
  # the wrong library.
  zlib,

  # 9.0 packs its script library into a ZIP image embedded in the interpreter
  # and needs a Tcl 9 to build it. The zipfs command itself is unaffected.
  zipfsImage ? true,

  # 8.6.0 and 8.6.1 emit only @TCL_VERSION@ into tcl.pc; 8.5 below them and
  # 8.6.2 above both carry the patch level.
  pkgConfigVersion ? version,

  reportedVersion ? version,

  version,
  sha256,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "tcl";
  inherit version;

  # 8.3.5 onwards publish tclX.Y.Z-src.tar.gz; older releases are tclX.Y.Z.tar.gz.
  src = fetchurl {
    urls = [
      "https://prdownloads.sourceforge.net/tcl/tcl${version}-src.tar.gz"
      "https://prdownloads.sourceforge.net/tcl/tcl${version}.tar.gz"
    ];
    inherit sha256;
  };

  # configure lives in unix/, and the unpacked directory is named for the
  # release rather than the tarball.
  setSourceRoot = "sourceRoot=$(echo */unix)";

  buildInputs = [ zlib ];

  configureFlags = lib.optional (!zipfsImage) "--disable-zipfs";

  # The bundled extensions configure themselves with a tclsh, which does not
  # exist until this build has produced one.
  buildPhase = ''
    runHook preBuild
    make binaries libraries doc
    export LD_LIBRARY_PATH="$PWD"
    make packages TCLSH_NATIVE="$PWD/tclsh"
    runHook postBuild
  '';

  # Upstream installs tclshX.Y only; every consumer looks for tclsh.
  postInstall = ''
    ln -s "$(basename "$out"/bin/tclsh*)" "$out/bin/tclsh"
  '';

  meta = {
    description = "Tool Command Language interpreter";
    homepage = "https://www.tcl-lang.org/";
    license = lib.licenses.tcltk;
    platforms = lib.platforms.unix;
  };

  passthru = {
    inherit version;
    tvp.deps = {
      inherit zlib;
    };
    tvp.cc = stdenv.cc;
    tvp.reportedVersion = reportedVersion;
    tvp.pkgConfigVersion = pkgConfigVersion;

    tvp.features = {
      zipfsImage = zipfsImage && lib.versionAtLeast version "9.0";
      pkgConfig = lib.versionAtLeast version "8.5.16";
      are = lib.versionAtLeast version "8.1";
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})
