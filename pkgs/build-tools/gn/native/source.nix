# Gitiles serves variable gzip headers. Hash the flat unpacked tree, exactly as
# the retained fetchzip stripRoot=false did; no root component is discarded.
{
  bash,
  coreutils,
  python,
  curl,
  caCertificates,
  revision,
  sha256,
}:
builtins.derivation {
  name = "gn-${revision}";
  system = "x86_64-linux";
  builder = "${bash}/bin/bash";
  args = [
    "-euc"
    ''
      export PATH=${coreutils}/bin
      export SSL_CERT_FILE=${caCertificates}/etc/ssl/certs/ca-bundle.crt
      ${curl}/bin/curl --fail --location --retry 2 --output archive.tar.gz \
        'https://gn.googlesource.com/gn/+archive/${revision}.tar.gz'
      ${python}/bin/python3 -B ${./unpack.py} archive.tar.gz "$out"
    ''
  ];
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = sha256;
  preferLocalBuild = true;
  impureEnvVars = [
    "http_proxy"
    "https_proxy"
    "HTTP_PROXY"
    "HTTPS_PROXY"
    "ALL_PROXY"
    "NO_PROXY"
    "NIX_SSL_CERT_FILE"
  ];
}
