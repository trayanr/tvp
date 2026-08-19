# Serves 3.0.0 to 3.47.2.
#
# The autoconf generation: 3.48.0 replaced configure with autosetup, which
# renamed every option this passes.
{
  lib,
  stdenv,
  fetchurl,

  # Native: the amalgamation is assembled by tool/mksqlite3c.tcl, and lemon and
  # the keyword hash are generated before it.
  tcl,

  readline,

  # Fossil records configure non-executable until 3.7.0, and stdenv skips a
  # configure it cannot exec.
  configureIsExecutable ? true,

  # src/shell.c passes a variable as the format string until 3.6.10, and
  # -Werror=format-security is the stdenv's policy rather than upstream's code.
  hardeningDisable ? [ ],

  # sqlite3.pc carries @VERSION@ — major.minor only — until 3.6.10 switched it
  # to @RELEASE@.
  pkgConfigMajorMinor ? false,

  # 3.1.0 and 3.1.1 ship VERSION files reading 3.1.0alpha and 3.1.1beta.
  reportedVersion ? version,

  patches ? [ ],

  version,
  sha256,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (
  finalAttrs:
  {
    pname = "sqlite";
    inherit version;

    # Fossil serves a tarball per tag; the requested filename becomes the root
    # directory inside it.
    src = fetchurl {
      name = "sqlite-${version}.tar.gz";
      url = "https://sqlite.org/src/tarball/sqlite-${version}.tar.gz?r=version-${version}";
      inherit sha256;
    };

    nativeBuildInputs = [ tcl ];
    buildInputs = [ readline ];

    # buildtclext.tcl installs into the first writable directory on tclsh's
    # auto_path, and every entry there is a store path.
    preConfigure = ''
      mkdir -p "$out/lib/tcl"
      export TCLLIBPATH="$out/lib/tcl"
    '';

    configureFlags = [
      "--enable-all"
      "--with-tclsh=${tcl}/bin/tclsh"
      "--with-readline-inc=-I${readline}/include"
      "--with-readline-lib=-lreadline"
    ];

    meta = {
      description = "Self-contained SQL database engine";
      homepage = "https://sqlite.org/";
      license = lib.licenses.publicDomain;
      platforms = lib.platforms.unix;
    };

    passthru = {
      inherit version;
      tvp.deps = {
        inherit tcl readline;
      };
      tvp.cc = stdenv.cc;
      tvp.reportedVersion = reportedVersion;
      tvp.pkgConfigVersion = if pkgConfigMajorMinor then lib.versions.majorMinor version else version;

      tvp.features = {
        pkgConfig = lib.versionAtLeast version "3.0.6";
        prepareV2 = lib.versionAtLeast version "3.3.9";
        libVersionFunction = lib.versionAtLeast version "3.0.8";
      };

      tests = mkTests finalAttrs.finalPackage;
    };
  }
  // lib.optionalAttrs (!configureIsExecutable) { postPatch = "chmod +x configure"; }
  // lib.optionalAttrs (hardeningDisable != [ ]) { inherit hardeningDisable; }
  // lib.optionalAttrs (patches != [ ]) { inherit patches; }
)
