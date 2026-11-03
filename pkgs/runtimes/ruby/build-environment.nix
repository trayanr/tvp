# Ruby is an explicitly activated build tool. Packages may publish Ruby-only
# relative layouts; discovery never evaluates installed files or setup hooks.
{ lib }:
{ tool, libraries, ... }:
let
  layout = package: package.rubyDevelopment or { };
  gemDirectories =
    package: map (directory: "${package}/${directory}") ((layout package).gemDirectories or [ ]);
  siteDirectories =
    package: map (directory: "${package}/${directory}") ((layout package).siteDirectories or [ ]);
in
{
  paths = {
    GEM_PATH = {
      separator = ":";
      entries = lib.concatMap gemDirectories libraries ++ [ "${tool}/${tool.gemPath}" ];
    };
    RUBYLIB = {
      separator = ":";
      entries = lib.concatMap siteDirectories libraries;
    };
  };
}
