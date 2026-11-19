args@{
  tvp,
  lib,
  base,
  src,
  version,
  php,
  extensionName,
  phpCompatibility,
  autoconf,
  automake,
  libtool,
  configureOptions ? [ ],
  patches ? [ ],
  libraries ? [ ],
  loader ? "extension",
  extensionMeta ? { },
  sourceMode ? "archive",
  compression ? "gzip",
}:
final:
import ../build-bundled.nix args (
  final
  // {
    # GNU libc supplies libintl.h and the gettext symbols on this platform.
    configureOptions = final.configureOptions ++ [ "--with-gettext=${lib.getDev final.base.libc}" ];
    # PHP 8.5 references the test locale through its full source-tree layout.
    patches =
      final.patches
      ++ lib.optional (lib.versions.majorMinor final.php.version == "8.5") ./standalone-locale-path.patch;
  }
)
