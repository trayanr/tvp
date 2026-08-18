# Serves 5.44 onwards.
#
# Configure is Perl's own, not autoconf: it is interactive unless given -des,
# and it spells the install prefix -Dprefix= rather than --prefix=.
{
  lib,
  stdenv,
  fetchurl,

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

  configureScript = "./Configure";
  prefixKey = "-Dprefix=";
  configurePlatforms = [ ];

  configureFlags = [
    "-des"
    "-Duseshrplib"
    # Configure otherwise probes the build host's /usr/local and bakes whatever
    # it finds into the resulting Config.pm.
    "-Dlocincpth= "
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
    tvp.deps = { };

    # `glob` sat in File::Glob's @EXPORT_OK until 5.30 removed it, so
    # `use File::Glob "glob"` stopped compiling. Not trivia: that is the line in
    # OpenSSL's Configure that TVP already patches out of 1.1.0g and earlier.
    tvp.features = {
      globImportable = lib.versionOlder version "5.30";
    };

    tests = mkTests finalAttrs.finalPackage;
  };
})
