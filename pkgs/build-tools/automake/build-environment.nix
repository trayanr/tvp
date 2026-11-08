# Explicit macro discovery for declared providers. No hook execution or global
# ACLOCAL_PATH mutation; callers may replace this composed path via overrides.
{ libraries, ... }:
{
  paths.ACLOCAL_PATH = {
    separator = ":";
    entries = builtins.concatMap (
      p: (p.development or { }).aclocalDirectories or [ "${p}/share/aclocal" ]
    ) libraries;
  };
}
