# Ordinary build-tool roles, selected once for every family using this base.
# These are lazy argument defaults, not additions to every step's PATH.
# Tools building themselves still select earlier construction providers explicitly.
{ tvp }:
{
  inherit (tvp.packages)
    gnumake
    gnutar
    xz
    diffutils
    findutils
    ;
  python = tvp.packages.python-build_3_12_5;
  patchelf = tvp.packages.patchelf_0;
  sed = tvp.packages.gnused;
  grep = tvp.packages.gnugrep;
  gawk = tvp.lib.packages.withConstraint {
    reason = "The standard build tools must precede MPFR; Gawk 5 depends on MPFR. Use the MPFR-free Gawk 4.0 line for the build-only AWK role.";
  } tvp.packages.gawk_4_0;
}
