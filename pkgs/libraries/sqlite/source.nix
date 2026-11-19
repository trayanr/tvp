{ fetchMirrors, certificates }:
{ version, sha256 }:
fetchMirrors {
  inherit certificates;
  name = "sqlite-${version}.tar.gz";
  urls = [
    "https://sqlite.org/src/tarball/version-${version}/sqlite-${version}.tar.gz"
    "https://www.sqlite.org/src/tarball/sqlite-${version}.tar.gz?r=version-${version}"
    "https://sqlite.org/src/tarball/sqlite-${version}.tar.gz?r=version-${version}"
  ];
  retries = 12;
  retryDelay = 5;
  inherit sha256;
}
