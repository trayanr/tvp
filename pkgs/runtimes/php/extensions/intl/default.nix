{ pkgs, tvp }:
import ../bundled-family.nix {
  inherit pkgs tvp;
  name = "intl";
  phpRequirements = {
    min = "5.3.0";
    reason = "PHP first bundled intl in 5.3.0.";
    source = "https://github.com/php/php-src/tree/php-5.3.0/ext/intl";
  };
  opts = {
    configureOptions = [ "--enable-intl" ];
    libraries = [ pkgs.icu ];
  };
  tests = import ./tests.nix { inherit tvp; };
  meta = {
    description = "PHP internationalization support through ICU";
    homepage = "https://www.php.net/manual/en/book.intl.php";
    license = pkgs.lib.licenses.php301;
  };
}
