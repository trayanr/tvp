# Serves 8.0.2 onwards.
#
# 8.5 has no bundled extensions and no `packages` make target, and its configure
# never looks for zlib.
{
  lib,
  stdenv,
  fetchurl,

  version,
  sha256,

  # 8.0.2 reports 8.0p2 — the patchlevel spelling its tarball also uses.
  reportedVersion ? version,

  patches ? [ ],

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (
  finalAttrs:
  {
    pname = "tcl";
    inherit version;

    # 8.3.5 onwards publish tclX.Y.Z-src.tar.gz; older releases are tclX.Y.Z.tar.gz.
    src = fetchurl {
      urls = [
        "https://prdownloads.sourceforge.net/tcl/tcl${version}-src.tar.gz"
        "https://prdownloads.sourceforge.net/tcl/tcl${version}.tar.gz"
        # 8.0.2 shipped as tcl8.0p2.tar.gz and 8.1.0 as tcl8.1.tar.gz. The
        # patchlevel form must be tried first: tcl8.0.tar.gz exists and is a
        # different release.
        "https://prdownloads.sourceforge.net/tcl/tcl${lib.versions.majorMinor version}p${lib.versions.patch version}.tar.gz"
        "https://prdownloads.sourceforge.net/tcl/tcl${lib.versions.majorMinor version}.tar.gz"
      ];
      inherit sha256;
    };

    # configure lives in unix/, and the unpacked directory is named for the
    # release rather than the tarball.
    setSourceRoot = "sourceRoot=$(echo */unix)";

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
      tvp.deps = { };
      tvp.cc = stdenv.cc;
      tvp.reportedVersion = reportedVersion;

      tvp.features = {
        zipfsImage = false;
        pkgConfig = lib.versionAtLeast version "8.5.16";
        are = lib.versionAtLeast version "8.1";
      };

      tests = mkTests finalAttrs.finalPackage;
    };
  }
  // lib.optionalAttrs (patches != [ ]) {
    inherit patches;
    # sourceRoot is unix/; the patches address the tree above it.
    patchFlags = [
      "-p1"
      "-d"
      ".."
    ];
  }
)
