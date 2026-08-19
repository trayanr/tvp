# Serves 1.0.1 onwards.
#
# zlib's `configure` is hand-written, not autoconf: it accepts --prefix,
# --libdir, --includedir, --shared and --static and rejects anything else, so
# the stdenv must not add its usual flags.
{
  lib,
  stdenv,
  fetchurl,

  version,
  sha256,

  patches ? [ ],

  # 1.2.4.4 accepts --sharedlibdir but never defaults it, so its install runs
  # `cp libz.so.1.2.4.4` with no destination.
  sharedLibDir ? false,

  # Releases before 1.2.3 take AR from the environment expecting it to carry
  # flags: `AR=${AR-"ar rc"}`. Modern stdenv exports AR=ar, the program alone,
  # so the archive is created as `ar libz.a *.o`.
  arCommand ? null,

  # 1.0 and 1.1 probe /usr/include by absolute path. The sandbox has no FHS,
  # so configure concludes errno.h is missing and defines NO_ERRNO_H, which
  # makes gzio.c declare `extern int errno` against glibc's thread-local one.
  assumeSystemHeaders ? false,

  # 1.1.1 and older hardcode prefix=/usr/local in the Makefile and have no
  # configure substitution for it.
  prefixInstallFlag ? false,

  # 1.0.8 and older write `if [ ! $(prefix)/include ]` without -d, so the test
  # is always false and the directories are never created.
  createInstallDirs ? false,

  # 1.0.5 and older declare `extern int errno` on every Unix; 1.0.6 switched to
  # including <errno.h>. glibc makes errno thread-local, so the old form does
  # not link.
  errnoHeader ? false,

  # 1.2.0 and 1.2.0.1 keep LDFLAGS=libz.a while --shared makes LIBS the shared
  # object, so the example programs link an archive configure did not build.
  linkAgainstLibs ? false,

  # 1.2.0.5 to 1.2.0.7 install the man page with plain mkdir, so the install
  # aborts unless share/man exists already.
  createManDir ? false,

  # 1.2.7.2 is the one release in the catalogue whose ZLIB_VERSION differs
  # from its tarball name.
  reportedVersion ? version,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
let
  postPatchSteps =
    lib.optional assumeSystemHeaders (
      "sed -i -e 's|test ! -f /usr/include/errno.h|false|' "
      + "-e 's|test -f /usr/include/unistd.h|true|' configure"
    )
    ++ lib.optional linkAgainstLibs "sed -i 's|^LDFLAGS=libz.a|LDFLAGS=$(LIBS)|' Makefile.in"
    ++ lib.optional errnoHeader "sed -i 's|extern int errno;|#include <errno.h>|' zutil.h";
in
stdenv.mkDerivation (
  finalAttrs:
  {
    pname = "zlib";
    inherit version;

    # zlib.net serves only current releases; fossils/ is upstream's own archive of
    # every tarball it has published, and covers the whole line from one pattern.
    src = fetchurl {
      url = "https://zlib.net/fossils/zlib-${version}.tar.gz";
      inherit sha256;
    };

    # --build/--host are autoconf spellings that this configure rejects outright.
    configurePlatforms = [ ];

    configureFlags = [
      "--shared"
    ] ++ lib.optional sharedLibDir "--sharedlibdir=${placeholder "out"}/lib";

    meta = {
      description = "Lossless data-compression library implementing the DEFLATE algorithm";
      homepage = "https://zlib.net/";
      license = lib.licenses.zlib;
      platforms = lib.platforms.unix;
    };

    passthru = {
      inherit version;
      tvp.deps = { };
      tvp.reportedVersion = reportedVersion;

      # zlib.pc arrived at 1.2.3.1. Before 1.2.3.3 `--shared` selected shared
      # *instead of* static, so those releases ship no libz.a; from 1.2.3.3 the
      # configure builds both and --shared is a no-op.
      tvp.features = {
        libName = "z";
        versionFunction = lib.versionAtLeast version "1.0.4";
        compress2 = lib.versionAtLeast version "1.0.8";
        pkgConfig = lib.versionAtLeast version "1.2.3.1";
        static = lib.versionAtLeast version "1.2.3.3";
      };

      tests = mkTests finalAttrs.finalPackage;
    };
  }
  // lib.optionalAttrs createInstallDirs {
    preInstall = "mkdir -p $out/include $out/lib";
  }
  // lib.optionalAttrs prefixInstallFlag {
    installFlags = [
      "prefix=${placeholder "out"}"
      "exec_prefix=${placeholder "out"}"
    ];
  }
  // lib.optionalAttrs (postPatchSteps != [ ]) {
    postPatch = lib.concatStringsSep "\n" postPatchSteps;
  }
  // lib.optionalAttrs (arCommand != null) {
    # preConfigure, not env: the bintools setup hook exports AR=ar after env.
    preConfigure = "export AR=${lib.escapeShellArg arCommand}";
  }
  // lib.optionalAttrs createManDir {
    preInstall = "mkdir -p $out/share/man/man3";
  }
  // lib.optionalAttrs (patches != [ ]) { inherit patches; }
)
