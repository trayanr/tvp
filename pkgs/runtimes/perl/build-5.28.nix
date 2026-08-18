# Serves up to 5.28.
#
# Errno_pm.PL dies outright when no errno.h is found under the FHS include
# paths. 5.30 hoisted that probe and falls through to the preprocessor instead.
# Rather than restructure it, locincpth names where this distribution actually
# keeps the C library headers.
#
# This fork is what a base does NOT remove. The other reason it once existed —
# Configure's `1*` gcc-version glob — is gone, because 5.28 now builds on
# bases.gcc9. Both remaining differences from build-5.30.nix are
# sandbox-shaped, and no choice of era fixes those.
#
# Cwd.pm runs `pwd` from a hardcoded list of FHS paths, and the build sandbox
# has no /bin. cwd() then returns empty and MakeMaker dies with "Can't figure
# out your cwd!" while configuring cpan/Encode. 5.36 and later build without
# the substitution. The path is the distribution's layout, not an upstream
# defect, so it is corrected rather than the source patched.
#
# Configure is Perl's own, not autoconf: it is interactive unless given -des,
# and it spells the install prefix -Dprefix= rather than --prefix=.
{
  lib,
  stdenv,
  fetchurl,
  coreutils,

  version,
  sha256,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "perl";
  inherit version;

  # cpan.metacpan.org rather than www.cpan.org: the official index has been
  # pruned of 31 releases it once served — their orphan .sha256.txt files are
  # still listed beside the missing tarball — and this mirror still has them.
  # Canonical host first, then a full mirror. www.cpan.org has been pruned of
  # 31 releases it once served — their orphan .sha256.txt files are still
  # listed beside the missing tarball — and the mirror still carries them all.
  src = fetchurl {
    urls = [
      "https://www.cpan.org/src/5.0/perl-${version}.tar.gz"
      "https://cpan.metacpan.org/src/5.0/perl-${version}.tar.gz"
    ];
    inherit sha256;
  };

  postPatch = ''
    substituteInPlace dist/PathTools/Cwd.pm \
      --replace-fail "/bin/pwd" "${coreutils}/bin/pwd"
  '';

  configureScript = "./Configure";
  prefixKey = "-Dprefix=";
  configurePlatforms = [ ];

  configureFlags = [
    "-des"
    "-Duseshrplib"
    # Names the C library headers explicitly: Errno_pm.PL searches the FHS
    # include paths and dies if none of them exists.
    "-Dlocincpth=${lib.getDev stdenv.cc.libc}/include"
    "-Dloclibpth= "
  ];

  meta = {
    description = "Highly capable, feature-rich programming language";
    homepage = "https://www.perl.org/";
    license = lib.licenses.artistic1;
    platforms = lib.platforms.unix;
    mainProgram = "perl";
  };

  passthru = {
    inherit version;
    tvp.deps = {
      inherit coreutils;
    };

    # `glob` sat in File::Glob's @EXPORT_OK until 5.30 removed it, so
    # `use File::Glob "glob"` stopped compiling. Not trivia: that is the line in
    # OpenSSL's Configure that TVP already patches out of 1.1.0g and earlier.
    tvp.features = {
      globImportable = lib.versionOlder version "5.30";
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})
