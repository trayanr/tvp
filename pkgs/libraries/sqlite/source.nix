{ fetchurl }:
{ version, sha256 }:
fetchurl {
  name = "sqlite-${version}.tar.gz";
  urls = [
    "https://sqlite.org/src/tarball/version-${version}/sqlite-${version}.tar.gz"
    "https://www.sqlite.org/src/tarball/sqlite-${version}.tar.gz?r=version-${version}"
    "https://sqlite.org/src/tarball/sqlite-${version}.tar.gz?r=version-${version}"
  ];
  curlOptsList = [
    "--retry"
    "12"
    "--retry-delay"
    "5"
  ];
  inherit sha256;
}
