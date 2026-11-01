# Serves 1.4.19 onwards.
{
  lib,
  stdenv,
  fetchurl,

  version,
  sha256,
  cStandard ? null,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (
  finalAttrs:
  {
    pname = "m4";
    inherit version;

    # ftp.gnu.org keeps every release it has ever published, so one pattern serves
    # the whole line.
    src = fetchurl {
      urls = [
        "https://mirrors.kernel.org/gnu/m4/m4-${version}.tar.gz"
        "https://ftp.gnu.org/gnu/m4/m4-${version}.tar.gz"
      ];
      inherit sha256;
    };

    meta = {
      description = "GNU macro processor";
      homepage = "https://www.gnu.org/software/m4/";
      license = lib.licenses.gpl3Plus;
      platforms = lib.platforms.unix;
      mainProgram = "m4";
    };

    passthru = {
      inherit version;
      tvp.deps = { };

      tests = mkTests finalAttrs.finalPackage;
    };
  }
  // lib.optionalAttrs (cStandard != null) { env.NIX_CFLAGS_COMPILE = "-std=${cStandard}"; }
)
