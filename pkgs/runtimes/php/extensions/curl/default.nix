{ pkgs, tvp }:
let
  curl = tvp.packages.curl;
in
import ../bundled-family.nix {
  inherit pkgs tvp;
  name = "curl";
  opts = {
    configureOptions = [ "--with-curl" ];
    # Older PHP cURL configure scripts also link OpenSSL directly.
    libraries = [ curl ] ++ curl.specification.runtime.libraries;
  };
  tests = import ./tests.nix { inherit tvp; };
  meta = {
    description = "PHP extension for libcurl transfers";
    homepage = "https://www.php.net/curl";
  };
}
