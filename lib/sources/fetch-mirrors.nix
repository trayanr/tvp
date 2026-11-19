# Source-built TLS Python precedes the catalogue Perl and Ncurses consumers of Curl.
{
  certificates,
  urls,
  sha256,
  name ? builtins.baseNameOf (builtins.head urls),
  retries ? 3,
  retryDelay ? 0,
}:
let
  python = (import ../../bootstrap/source-python-meson.nix { }).python;
in
assert urls != [ ];
assert builtins.all (url: builtins.match "https://[^[:space:]]+" url != null) urls;
assert builtins.isInt retries && retries >= 0;
assert builtins.isInt retryDelay && retryDelay >= 0;
builtins.derivation {
  inherit name urls;
  inherit (python) system;
  builder = "${python}/bin/python3";
  args = [
    "-IB"
    ./download-mirrors.py
    "${certificates}/etc/ssl/certs/ca-bundle.crt"
    (toString retries)
    (toString retryDelay)
  ]
  ++ urls;
  outputHashMode = "flat";
  outputHashAlgo = "sha256";
  outputHash = sha256;
  preferLocalBuild = true;
  impureEnvVars = [
    "http_proxy"
    "https_proxy"
    "all_proxy"
    "no_proxy"
    "HTTP_PROXY"
    "HTTPS_PROXY"
    "ALL_PROXY"
    "NO_PROXY"
  ];
}
