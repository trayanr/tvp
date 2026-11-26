# Network access is confined to this hash-pinned Go module source input.
{
  version,
  src,
  sha256,
  base,
  go,
  certificates,
}:
builtins.derivation {
  name = "grype-${version}-vendor";
  system = base.platform.system;
  builder = "${base.shell}/bin/bash";
  args = [
    "-euc"
    ''
      export PATH=${base.coreutils}/bin:${base.tools.gnutar}/bin:${base.tools.gzip}/bin
      export SSL_CERT_FILE=${certificates}/etc/ssl/certs/ca-bundle.crt
      export SSL_CERT_DIR=${certificates}/etc/ssl/certs
      export GOCACHE="$TMPDIR/go-cache" GOPATH="$TMPDIR/go-path" GOMODCACHE="$TMPDIR/go-modules"
      export GOENV=off GOTOOLCHAIN=local GOPROXY=https://proxy.golang.org GOSUMDB=sum.golang.org
      mkdir source
      tar -xzf ${src} --strip-components=1 -C source
      chmod -R u+w source
      cd source
      cp go.mod go.mod.original
      cp go.sum go.sum.original
      ${go}/bin/go mod vendor
      ${base.tools.diffutils}/bin/cmp go.mod.original go.mod
      ${base.tools.diffutils}/bin/cmp go.sum.original go.sum
      mv vendor "$out"
    ''
  ];
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = sha256;
  preferLocalBuild = true;
  impureEnvVars = [
    "https_proxy"
    "http_proxy"
    "all_proxy"
    "no_proxy"
  ];
}
