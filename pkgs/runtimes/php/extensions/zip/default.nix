{ pkgs, tvp }:
import ../bundled-family.nix {
  inherit pkgs tvp;
  name = "zip";
  phpRequirements = {
    min = "5.2";
    reason = "The bundled Zip extension for creating and editing archives was introduced in PHP 5.2.";
    source = "https://www.php.net/releases/5_2_0.php";
  };
  opts = {
    configureOptions = [ "--with-zip" ];
    libraries = [ tvp.packages.libzip ];
  };
  tests = import ./tests.nix { inherit tvp; };
  meta = {
    description = "PHP extension for reading and writing ZIP archives";
    homepage = "https://www.php.net/zip";
  };
}
