{ lib, pkgs, ... }:
let
  library = import ../native-library.nix { inherit lib; };
  check = import ../test.nix { inherit lib; };
  provider =
    name:
    if pkgs == null then
      throw "TVP Ruby nokogiri: provide ${name} explicitly or use the full TVP package context"
    else
      pkgs.${name};
in
{
  inputs = {
    libxml2 = _: provider "libxml2";
    libxslt = _: provider "libxslt";
    zlib = _: provider "zlib";
  };
  configure = final: {
    libraries = map library [
      final.libxml2
      final.libxslt
      final.zlib
    ];
    buildFlags = [ "--use-system-libraries" ];
    # libxml2 2.12 made structured error callback inputs const. Keep the patch
    # on the source version it was verified against, not arbitrary releases.
    patches = lib.optionals (
      final.version == "1.15.7"
      && final.platform == "ruby"
      && lib.versionAtLeast (final.libxml2.version or "0") "2.12"
    ) [ ./libxml-const-errors.patch ];
  };
  mkTests = package: {
    load = check package {
      name = "xml-library";
      script = ''
        ${package.ruby}/bin/ruby -rnokogiri -e '
          document = Nokogiri::XML("<answer>42</answer>")
          abort "Nokogiri parse failed" unless document.at_xpath("/answer").text == "42"
          print "nokogiri-loaded"
        '
      '';
      expected = "nokogiri-loaded";
    };
  };
}
