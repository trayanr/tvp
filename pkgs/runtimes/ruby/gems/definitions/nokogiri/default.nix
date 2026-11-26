{ lib, ... }:
let
  check = import ../test.nix { inherit lib; };
  defaultXslt =
    args:
    if args.version == "1.15.7" then
      # This gem predates the libxml2 2.13 API removals. The selected libxslt
      # declares its matching libxml2, preserving one XML provider in Ruby.
      args.tvp.packages.libxslt_1_1_43
    else
      args.tvp.packages.libxslt;
in
{
  inputs = {
    libxml2 = args: (args.libxslt or (defaultXslt args)).specification.libxml2;
    libxslt = defaultXslt;
    zlib = args: args.tvp.packages.zlib_1;
  };
  configure = final: {
    libraries = [
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
