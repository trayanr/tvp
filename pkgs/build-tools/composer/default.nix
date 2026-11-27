{ tvp, ... }:
let
  pname = "composer";
  downloads = "https://getcomposer.org/download/";
  pharLink = ''href="/download/([0-9]+[.][0-9]+[.][0-9]+)/composer[.]phar"'';
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          php = tvp.lib.packages.withConstraint {
            reason = "Pin a common PHP 8.3 runtime within Composer 2.7's declared ^7.2.5 || ^8.0 range for all of these releases and their installed checks.";
          } tvp.packages.php_8_3_36;
          unzip = tvp.packages.unzip;
        };
        blob = {
          reason = "The unchanged official PHAR bundles PHP sources and Symfony Console's precompiled Windows-only hiddeninput.exe.";
          needs = "A locked source dependency set and a Linux PHAR assembly that omits or replaces the Windows helper.";
        };
      };
      releases = {
        "2.7.0" = "sha256-L8UBy+8YkTeVI+5JidN78EeYQVoF+OtErnWssv3yWW8=";
        "2.7.1" = "sha256-H/0L4/J+I3sa5H+ejyn5asf1CgvZ7vT4jNvpTdBL//A=";
        "2.7.2" = "sha256-BJuODtnyZNdwoFEIWM/7w1QBUQdZ7cmnhLOlxuAgvKw=";
        "2.7.3" = "sha256-/MAv8ES1oE++z/AVjLYEHCXo94rElAmHNv7NK7TzgeQ=";
        "2.7.4" = "sha256-7gEIDWMtK7+pxhgAnMoTcY8251HdpnmmAJzudRwTstk=";
        "2.7.5" = "sha256-DcH2vLeibuFlIGAQITxgaaU3v45lM1KHOahk8VRUm3c=";
        "2.7.6" = "sha256-KdyaGe8zU12wYbMRgLKoM6fPjSz0FFszovg1BId7ugg=";
        "2.7.7" = "sha256-qrlAzVPShaVMUEZYIKIID8txgqS6Hl95Wr+xBBSktL4=";
        "2.7.8" = "sha256-PaNdwqu5nY7z/bHewxZsORiffLKZdKIl57vKBMGyxuA=";
        "2.7.9" = "sha256-tt5eZcGZ2AuhGJf74TZOBj6FjUg/aoGhdsTWDysdY0c=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "${downloads}${version}/composer.phar";
      discovery = {
        type = "directory-index";
        url = downloads;
        scope = "Stable PHAR releases listed on the Composer downloads page";
        pattern = pharLink;
        normalise =
          link:
          let
            match = builtins.match pharLink link;
          in
          if match == null then null else builtins.head match;
      };
    };
    tests = import ./tests;
    testDeps.zip = tvp.packages.zip;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
