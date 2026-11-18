{ pkgs, tvp }:
import ../bundled-family.nix {
  inherit pkgs tvp;
  name = "mbstring";
  opts = {
    configureOptions = [
      "--enable-mbstring"
      "--enable-mbregex"
    ];
    libraries = [ pkgs.oniguruma ];
  };
  tests = import ./tests.nix { inherit tvp; };
  meta = {
    description = "PHP multibyte text and regular expression support";
    homepage = "https://www.php.net/manual/en/book.mbstring.php";
    license = pkgs.lib.licenses.php301;
  };
}
