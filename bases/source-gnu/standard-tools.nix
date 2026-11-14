# Build-only roles come from the explicit preceding native generation. Ordinary
# libraries/runtime dependencies still use TVP package selectors in their tables.
# Public tools can depend on GMP (Coreutils, then Gzip/Diffutils/Findutils) or MPFR
# (Gawk5), so using their final aliases here would make the foundational families
# build themselves. These are lazy defaults, not a global PATH/tool list.
{ tvp }:
{
  inherit (tvp.baseTiers.native.standardTools)
    gnumake
    gnutar
    xz
    gzip
    bzip2
    patch
    python
    patchelf
    sed
    grep
    gawk
    diffutils
    findutils
    ;
}
