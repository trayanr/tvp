{ tvp, ... }:
let
  pname = "gradle";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-9.3.1-current.nix;
        deps = {
          jdk = tvp.packages.jdk_21;
          python = tvp.packages.python_3;
          unzip = tvp.packages.unzip;
        };
        blob = {
          reason = "Pinned upstream Gradle distribution with its bundled Java bytecode and native service libraries.";
          needs = "Source Gradle bootstrap and a locked source dependency repository.";
          blocked.package = "gradle-from-source";
        };
      };
      releases = {
        "9.3.1" = "sha256-F/J3hn9pFNYbGqAu+rG6e7Q5rWUspIXNjKaEL8zsbkM=";
      };
    }
  ];
  testDeps = {
    grep = tvp.packages.gnugrep;
    sed = tvp.packages.gnused;
    findutils = tvp.packages.findutils;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://services.gradle.org/distributions/gradle-${version}-all.zip";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."gradle" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
